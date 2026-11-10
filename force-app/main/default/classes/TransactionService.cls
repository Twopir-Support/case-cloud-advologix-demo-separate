/**
 * Transactions: one reporting table of estimates (budgets) and actuals (time, expenses, recurring fees)
 * plus billed amounts (invoice lines). Rebuilt nightly by TransactionsBatch or on demand per matter.
 */
public with sharing class TransactionService {

    @AuraEnabled
    public static Integer refreshMatter(Id matterId) {
        try {
            return rebuild(new Set<Id>{ matterId });
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @InvocableMethod(label='Refresh All Transactions' description='Rebuilds the Transactions table for every matter in the background.' category='Matter Management')
    public static List<Id> refreshAll(List<String> ignored) {
        return new List<Id>{ Database.executeBatch(new TransactionsBatch(), 50) };
    }

    public static Integer rebuild(Set<Id> matterIds) {
        delete [SELECT Id FROM Transaction__c WHERE Matter__c IN :matterIds];
        Map<Id, Matter__c> matters = new Map<Id, Matter__c>([SELECT Id, Primary_Account__c FROM Matter__c WHERE Id IN :matterIds]);
        List<Transaction__c> tx = new List<Transaction__c>();
        for (Time__c t : [SELECT Id, Matter__c, Timekeeper__c, Entry_Date__c, Time_in_Hours__c, Total_Amount__c, Task_Code__r.Name, Narrative__c
                          FROM Time__c WHERE Matter__c IN :matterIds]) {
            tx.add(row(matters.get(t.Matter__c), t.Id, 'Actual', 'Time', t.Entry_Date__c, t.Time_in_Hours__c, t.Total_Amount__c, null,
                t.Task_Code__r?.Name, t.Narrative__c, t.Timekeeper__c));
        }
        for (Expense__c e : [SELECT Id, Matter__c, Expense_Date__c, Amount__c, Expense_Code__r.Name, Description__c, Category__c
                             FROM Expense__c WHERE Matter__c IN :matterIds]) {
            tx.add(row(matters.get(e.Matter__c), e.Id, 'Actual', 'Expense', e.Expense_Date__c, null, null, e.Amount__c,
                e.Expense_Code__r?.Name, e.Description__c == null ? e.Category__c : e.Description__c, null));
        }
        for (Recurrence_Transaction__c r : [SELECT Id, Matter__c, Transaction_Date__c, Amount__c, Description__c
                                            FROM Recurrence_Transaction__c WHERE Matter__c IN :matterIds]) {
            tx.add(row(matters.get(r.Matter__c), r.Id, 'Actual', 'Recurrence Transaction', r.Transaction_Date__c, null, r.Amount__c, null, null, r.Description__c, null));
        }
        Set<Id> budgetsWithDetails = new Set<Id>();
        for (Budget_Detail__c d : [SELECT Id, Budget__c, Budget__r.Matter__c, Budget__r.Budget_Start__c, Hours__c, Fee_Amount__c, Expense_Amount__c,
                                   UTBMS_Code__r.Name, Description__c
                                   FROM Budget_Detail__c WHERE Budget__r.Matter__c IN :matterIds AND Budget__r.Active__c = true]) {
            budgetsWithDetails.add(d.Budget__c);
            tx.add(row(matters.get(d.Budget__r.Matter__c), d.Id, 'Estimate', 'Budget Detail', d.Budget__r.Budget_Start__c, d.Hours__c,
                d.Fee_Amount__c, d.Expense_Amount__c, d.UTBMS_Code__r?.Name, d.Description__c, null));
        }
        for (Budget__c b : [SELECT Id, Name, Matter__c, Budget_Start__c, Fee_Budget__c, Expense_Budget__c FROM Budget__c
                            WHERE Matter__c IN :matterIds AND Active__c = true]) {
            if (!budgetsWithDetails.contains(b.Id)) {
                tx.add(row(matters.get(b.Matter__c), b.Id, 'Estimate', 'Budget', b.Budget_Start__c, null, b.Fee_Budget__c, b.Expense_Budget__c, null, b.Name, null));
            }
        }
        for (Invoice_Line_Item__c l : [SELECT Id, Invoice__r.Matter__c, Line_Date__c, Line_Type__c, Quantity__c, Amount__c, UTBMS_Code__c, Description__c, Timekeeper__c
                                       FROM Invoice_Line_Item__c WHERE Invoice__r.Matter__c IN :matterIds AND Invoice__r.Status__c != 'Void']) {
            Boolean fee = l.Line_Type__c == 'Fee';
            tx.add(row(matters.get(l.Invoice__r.Matter__c), l.Id, 'Billed', 'Invoice Line Item', l.Line_Date__c, fee ? l.Quantity__c : null,
                fee ? l.Amount__c : null, fee ? null : l.Amount__c, l.UTBMS_Code__c, l.Description__c, l.Timekeeper__c));
        }
        insert tx;
        return tx.size();
    }

    private static Transaction__c row(Matter__c m, Id sourceId, String kind, String source, Date d, Decimal hours, Decimal fee, Decimal expense,
                                      String code, String description, Id timekeeper) {
        return new Transaction__c(Matter__c = m.Id, Account__c = m.Primary_Account__c, Transaction_Type__c = kind, Source__c = source,
            Source_Record_Id__c = sourceId, Transaction_Date__c = d, Hours__c = hours, Fee_Amount__c = fee, Expense_Amount__c = expense,
            UTBMS_Code__c = code == null ? null : code.left(20), Description__c = description == null ? null : description.left(255),
            Timekeeper__c = timekeeper);
    }
}
