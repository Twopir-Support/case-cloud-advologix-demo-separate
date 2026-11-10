/**
 * Builds a draft invoice from a matter's unbilled time and expenses, applying the matter's
 * default fee arrangement:
 *   Hourly / Retainer : time billed at its rate, less any discount %
 *   Capped Fee        : as hourly, then fees above the cap (across all invoices) are written off
 *   Fixed Fee         : one fixed-fee line on the first invoice; time is listed at zero
 *   Contingency       : time is left unbilled (recovered from settlement); only expenses are invoiced
 * Voiding an invoice returns its time and expenses to Unprocessed.
 */
public with sharing class BillingService {
    public class BillingException extends Exception {}

    public class Request {
        @InvocableVariable(required=true label='Matter Id')
        public Id matterId;
        @InvocableVariable(label='Bill Through Date (default today)')
        public Date throughDate;
    }

    @AuraEnabled
    public static Id generateInvoice(Id matterId) {
        try {
            return createInvoice(matterId, Date.today());
        } catch (Exception e) {
            throw aura(e);
        }
    }

    @AuraEnabled
    public static void voidInvoice(Id invoiceId) {
        try {
            voidInvoices(new Set<Id>{ invoiceId });
        } catch (Exception e) {
            throw aura(e);
        }
    }

    @InvocableMethod(label='Generate Matter Invoice' description='Creates a draft invoice from unbilled time and expenses.' category='Matter Management')
    public static List<Id> generateFromFlow(List<Request> requests) {
        List<Id> ids = new List<Id>();
        for (Request r : requests) {
            ids.add(createInvoice(r.matterId, r.throughDate == null ? Date.today() : r.throughDate));
        }
        return ids;
    }

    private static AuraHandledException aura(Exception e) {
        AuraHandledException ex = new AuraHandledException(e.getMessage());
        ex.setMessage(e.getMessage());
        return ex;
    }

    public static Id createInvoice(Id matterId, Date throughDate) {
        Matter__c m = [SELECT Id, Name, Primary_Account__c FROM Matter__c WHERE Id = :matterId];
        List<Matter_Fee_Arrangement__c> mfas = [
            SELECT Id, Fee_Type__c, Fee_Arrangement_Price__c, Cap_Amount__c, Discount_Percentage__c, NextBillDate__c
            FROM Matter_Fee_Arrangement__c
            WHERE Matter__c = :matterId AND Default_for_Fees__c = true
            ORDER BY CreatedDate LIMIT 1
        ];
        Matter_Fee_Arrangement__c mfa = mfas.isEmpty() ? null : mfas[0];
        String feeType = (mfa == null || mfa.Fee_Type__c == null) ? 'Hourly' : mfa.Fee_Type__c;
        Boolean isFixed = feeType == 'Fixed Fee';
        Boolean billTime = feeType != 'Contingency';

        List<Time__c> times = !billTime ? new List<Time__c>() : [
            SELECT Id, Entry_Date__c, Time_in_Hours__c, Rate__c, Total_Amount__c, Narrative__c, Timekeeper__c, Task_Code__r.Name
            FROM Time__c
            WHERE Matter__c = :matterId AND Status__c = 'Unprocessed'
                AND Disposition__c IN ('Bill', 'No Charge') AND Entry_Date__c <= :throughDate
            ORDER BY Entry_Date__c
        ];
        List<Expense__c> expenses = [
            SELECT Id, Expense_Date__c, Amount__c, Description__c, Category__c, Disposition__c, Expense_Code__r.Name
            FROM Expense__c
            WHERE Matter__c = :matterId AND Status__c = 'Unprocessed'
                AND Disposition__c IN ('Bill', 'No Charge') AND Expense_Date__c <= :throughDate
            ORDER BY Expense_Date__c
        ];
        Boolean addFixedLine = isFixed && mfa.Fee_Arrangement_Price__c != null && mfa.NextBillDate__c == null && [
            SELECT COUNT() FROM Invoice_Line_Item__c
            WHERE Invoice__r.Matter__c = :matterId AND Invoice__r.Status__c != 'Void'
                AND Line_Type__c = 'Fee' AND Time__c = null
        ] == 0;

        List<Recurrence_Transaction__c> recurring = [
            SELECT Id, Transaction_Date__c, Amount__c, Description__c FROM Recurrence_Transaction__c
            WHERE Matter__c = :matterId AND Status__c = 'Unprocessed' AND Transaction_Date__c <= :throughDate
            ORDER BY Transaction_Date__c
        ];
        if (times.isEmpty() && expenses.isEmpty() && !addFixedLine && recurring.isEmpty()) {
            throw new BillingException('There is no unbilled time or expense on ' + m.Name + ' up to ' + throughDate.format() + '.');
        }

        Date periodStart = throughDate;
        for (Time__c t : times) {
            if (t.Entry_Date__c < periodStart) periodStart = t.Entry_Date__c;
        }
        for (Expense__c e : expenses) {
            if (e.Expense_Date__c < periodStart) periodStart = e.Expense_Date__c;
        }

        Invoice__c inv = new Invoice__c(
            Matter__c = matterId,
            Account__c = m.Primary_Account__c,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Period_Start__c = periodStart,
            Period_End__c = throughDate,
            Status__c = 'Draft',
            Amount_Paid__c = 0
        );
        insert inv;

        List<Invoice_Line_Item__c> lines = new List<Invoice_Line_Item__c>();
        Decimal fees = 0;
        Decimal expenseTotal = 0;
        if (addFixedLine) {
            lines.add(new Invoice_Line_Item__c(Invoice__c = inv.Id, Line_Type__c = 'Fee', Line_Date__c = Date.today(),
                Description__c = 'Fixed fee per engagement agreement', Quantity__c = 1,
                Rate__c = mfa.Fee_Arrangement_Price__c, Amount__c = mfa.Fee_Arrangement_Price__c));
            fees += mfa.Fee_Arrangement_Price__c;
        }
        for (Recurrence_Transaction__c rc : recurring) {
            Decimal amount = rc.Amount__c == null ? 0 : rc.Amount__c;
            lines.add(new Invoice_Line_Item__c(Invoice__c = inv.Id, Line_Type__c = 'Fee', Line_Date__c = rc.Transaction_Date__c,
                Description__c = String.isBlank(rc.Description__c) ? 'Recurring fee' : rc.Description__c.left(255),
                Quantity__c = 1, Rate__c = amount, Amount__c = amount));
            fees += amount;
            rc.Status__c = 'Billed';
            rc.Invoice__c = inv.Id;
            if (rc.Transaction_Date__c < periodStart) {
                periodStart = rc.Transaction_Date__c;
                inv.Period_Start__c = periodStart;
            }
        }
        for (Time__c t : times) {
            Decimal amount = isFixed || t.Total_Amount__c == null ? 0 : t.Total_Amount__c;
            lines.add(new Invoice_Line_Item__c(Invoice__c = inv.Id, Line_Type__c = 'Fee', Time__c = t.Id,
                Timekeeper__c = t.Timekeeper__c, Line_Date__c = t.Entry_Date__c,
                Description__c = t.Narrative__c == null ? null : t.Narrative__c.left(255),
                Quantity__c = t.Time_in_Hours__c, Rate__c = isFixed ? 0 : t.Rate__c, Amount__c = amount,
                UTBMS_Code__c = t.Task_Code__r?.Name));
            fees += amount;
            t.Status__c = 'Billed';
            t.Invoice__c = inv.Id;
        }
        for (Expense__c e : expenses) {
            Decimal amount = e.Disposition__c == 'No Charge' || e.Amount__c == null ? 0 : e.Amount__c;
            String description = String.isNotBlank(e.Description__c) ? e.Description__c : e.Category__c;
            lines.add(new Invoice_Line_Item__c(Invoice__c = inv.Id, Line_Type__c = 'Expense', Expense__c = e.Id,
                Line_Date__c = e.Expense_Date__c, Description__c = description == null ? null : description.left(255),
                Quantity__c = 1, Rate__c = amount, Amount__c = amount, UTBMS_Code__c = e.Expense_Code__r?.Name));
            expenseTotal += amount;
            e.Status__c = 'Billed';
            e.Invoice__c = inv.Id;
        }

        Decimal discount = 0;
        if (mfa != null && !isFixed && mfa.Discount_Percentage__c != null) {
            discount = (fees * mfa.Discount_Percentage__c / 100).setScale(2);
        }
        if (feeType == 'Capped Fee' && mfa.Cap_Amount__c != null) {
            Decimal prior = 0;
            for (Invoice__c p : [
                SELECT Total_Amount__c, Expenses_Subtotal__c FROM Invoice__c
                WHERE Matter__c = :matterId AND Status__c != 'Void' AND Id != :inv.Id
            ]) {
                prior += (p.Total_Amount__c == null ? 0 : p.Total_Amount__c) - (p.Expenses_Subtotal__c == null ? 0 : p.Expenses_Subtotal__c);
            }
            Decimal over = prior + fees - discount - mfa.Cap_Amount__c;
            if (over > 0) {
                discount = Math.min(fees, discount + over);
            }
        }

        insert lines;
        update recurring;
        update times;
        update expenses;
        inv.Discount_Amount__c = discount;
        inv.Total_Amount__c = fees - discount + expenseTotal;
        update inv;
        if (mfa != null) {
            update new Matter_Fee_Arrangement__c(Id = mfa.Id, LastBillDate__c = Date.today());
        }
        return inv.Id;
    }

    public static void voidInvoices(Set<Id> invoiceIds) {
        List<Invoice__c> invoices = [SELECT Id, Name, Status__c, Amount_Paid__c FROM Invoice__c WHERE Id IN :invoiceIds];
        for (Invoice__c inv : invoices) {
            if (inv.Status__c == 'Void') {
                throw new BillingException(inv.Name + ' is already void.');
            }
            if (inv.Amount_Paid__c != null && inv.Amount_Paid__c > 0) {
                throw new BillingException(inv.Name + ' has payments recorded and cannot be voided.');
            }
            inv.Status__c = 'Void';
        }
        List<Time__c> times = [SELECT Id FROM Time__c WHERE Invoice__c IN :invoiceIds];
        for (Time__c t : times) {
            t.Status__c = 'Unprocessed';
            t.Invoice__c = null;
        }
        List<Expense__c> expenses = [SELECT Id FROM Expense__c WHERE Invoice__c IN :invoiceIds];
        for (Expense__c e : expenses) {
            e.Status__c = 'Unprocessed';
            e.Invoice__c = null;
        }
        List<Recurrence_Transaction__c> recurring = [SELECT Id FROM Recurrence_Transaction__c WHERE Invoice__c IN :invoiceIds];
        for (Recurrence_Transaction__c rc : recurring) {
            rc.Status__c = 'Unprocessed';
            rc.Invoice__c = null;
        }
        update times;
        update expenses;
        update recurring;
        update invoices;
    }
}
