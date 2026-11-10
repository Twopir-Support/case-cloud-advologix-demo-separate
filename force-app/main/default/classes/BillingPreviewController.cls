/** Billing Preview: unbilled and billed time and expenses grouped by account and matter, with mass disposition updates. */
public with sharing class BillingPreviewController {

    public class Line {
        @AuraEnabled public Id id;
        @AuraEnabled public String kind;
        @AuraEnabled public String name;
        @AuraEnabled public Date lineDate;
        @AuraEnabled public String who;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String disposition;
        @AuraEnabled public String status;
        @AuraEnabled public String narrative;
    }
    public class MatterGroup {
        @AuraEnabled public Id matterId;
        @AuraEnabled public String name;
        @AuraEnabled public String matterNumber;
        @AuraEnabled public Decimal hours = 0;
        @AuraEnabled public Decimal timeTotal = 0;
        @AuraEnabled public Decimal expenseTotal = 0;
        @AuraEnabled public List<Line> lines = new List<Line>();
    }
    public class AccountGroup {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal total = 0;
        @AuraEnabled public List<MatterGroup> matters = new List<MatterGroup>();
    }

    @AuraEnabled
    public static List<AccountGroup> getPreview(Id recordId, Date startDate, Date endDate, List<String> dispositions,
                                                List<String> statuses, Boolean showTime, Boolean showExpense) {
        Date s = startDate == null ? Date.today().toStartOfMonth().addMonths(-2) : startDate;
        Date e = endDate == null ? Date.today() : endDate;
        List<String> disp = dispositions == null || dispositions.isEmpty() ? new List<String>{ 'Bill', 'Do Not Bill', 'Hold', 'No Charge' } : dispositions;
        List<String> stat = statuses == null || statuses.isEmpty() ? new List<String>{ 'Unprocessed' } : statuses;
        Id accountId = recordId != null && recordId.getSObjectType() == Account.SObjectType ? recordId : null;
        Id matterId = recordId != null && recordId.getSObjectType() == Matter__c.SObjectType ? recordId : null;

        Map<String, Object> binds = new Map<String, Object>{ 's' => s, 'e' => e, 'disp' => disp, 'stat' => stat, 'matterId' => matterId, 'accountId' => accountId };
        String scope = matterId != null ? ' AND Matter__c = :matterId' : (accountId != null ? ' AND Matter__r.Primary_Account__c = :accountId' : '');
        Map<Id, AccountGroup> accounts = new Map<Id, AccountGroup>();
        Map<Id, MatterGroup> matters = new Map<Id, MatterGroup>();
        if (showTime != false) {
            for (Time__c t : (List<Time__c>) Database.queryWithBinds('SELECT Id, Name, Matter__c, Matter__r.Name, Matter__r.Matter_Number__c, Matter__r.Primary_Account__c, '
                    + 'Matter__r.Primary_Account__r.Name, Entry_Date__c, Timekeeper__r.Name, Time_in_Hours__c, Rate__c, Total_Amount__c, Disposition__c, Status__c, Narrative__c '
                    + 'FROM Time__c WHERE Entry_Date__c >= :s AND Entry_Date__c <= :e AND Disposition__c IN :disp AND Status__c IN :stat' + scope
                    + ' ORDER BY Entry_Date__c LIMIT 1000', binds, AccessLevel.USER_MODE)) {
                MatterGroup g = groupFor(accounts, matters, t.Matter__c, t.Matter__r.Name, t.Matter__r.Matter_Number__c,
                    t.Matter__r.Primary_Account__c, t.Matter__r.Primary_Account__r?.Name);
                Line l = new Line();
                l.id = t.Id; l.kind = 'Time'; l.name = t.Name; l.lineDate = t.Entry_Date__c; l.who = t.Timekeeper__r?.Name;
                l.hours = t.Time_in_Hours__c; l.rate = t.Rate__c; l.amount = t.Total_Amount__c == null ? 0 : t.Total_Amount__c;
                l.disposition = t.Disposition__c; l.status = t.Status__c; l.narrative = t.Narrative__c;
                g.lines.add(l);
                g.hours += t.Time_in_Hours__c == null ? 0 : t.Time_in_Hours__c;
                if (t.Disposition__c != 'Do Not Bill') {
                    g.timeTotal += l.amount;
                }
            }
        }
        if (showExpense != false) {
            for (Expense__c x : (List<Expense__c>) Database.queryWithBinds('SELECT Id, Name, Matter__c, Matter__r.Name, Matter__r.Matter_Number__c, Matter__r.Primary_Account__c, '
                    + 'Matter__r.Primary_Account__r.Name, Expense_Date__c, Category__c, Amount__c, Disposition__c, Status__c, Description__c '
                    + 'FROM Expense__c WHERE Expense_Date__c >= :s AND Expense_Date__c <= :e AND Disposition__c IN :disp AND Status__c IN :stat' + scope
                    + ' ORDER BY Expense_Date__c LIMIT 1000', binds, AccessLevel.USER_MODE)) {
                MatterGroup g = groupFor(accounts, matters, x.Matter__c, x.Matter__r.Name, x.Matter__r.Matter_Number__c,
                    x.Matter__r.Primary_Account__c, x.Matter__r.Primary_Account__r?.Name);
                Line l = new Line();
                l.id = x.Id; l.kind = 'Expense'; l.name = x.Name; l.lineDate = x.Expense_Date__c; l.who = x.Category__c;
                l.amount = (x.Disposition__c == 'No Charge' || x.Amount__c == null) ? 0 : x.Amount__c;
                l.disposition = x.Disposition__c; l.status = x.Status__c; l.narrative = x.Description__c;
                g.lines.add(l);
                if (x.Disposition__c != 'Do Not Bill') {
                    g.expenseTotal += l.amount;
                }
            }
        }
        for (AccountGroup a : accounts.values()) {
            for (MatterGroup g : a.matters) {
                a.total += g.timeTotal + g.expenseTotal;
            }
        }
        return accounts.values();
    }

    private static MatterGroup groupFor(Map<Id, AccountGroup> accounts, Map<Id, MatterGroup> matters, Id matterId, String matterName,
                                        String matterNumber, Id accountId, String accountName) {
        MatterGroup g = matters.get(matterId);
        if (g != null) {
            return g;
        }
        Id key = accountId == null ? matterId : accountId;
        AccountGroup a = accounts.get(key);
        if (a == null) {
            a = new AccountGroup();
            a.accountId = accountId;
            a.name = accountName == null ? 'No client account' : accountName;
            accounts.put(key, a);
        }
        g = new MatterGroup();
        g.matterId = matterId;
        g.name = matterName;
        g.matterNumber = matterNumber;
        matters.put(matterId, g);
        a.matters.add(g);
        return g;
    }

    /** Sets the disposition on selected time and expense records. Billed records are skipped. Returns the number updated. */
    @AuraEnabled
    public static Integer updateDisposition(List<Id> recordIds, String disposition) {
        List<SObject> rows = new List<SObject>();
        for (Time__c t : [SELECT Id FROM Time__c WHERE Id IN :recordIds AND Status__c != 'Billed']) {
            rows.add(new Time__c(Id = t.Id, Disposition__c = disposition));
        }
        for (Expense__c x : [SELECT Id FROM Expense__c WHERE Id IN :recordIds AND Status__c != 'Billed']) {
            rows.add(new Expense__c(Id = x.Id, Disposition__c = disposition));
        }
        Integer ok = 0;
        for (Database.SaveResult sr : Database.update(rows, false)) {
            if (sr.isSuccess()) {
                ok++;
            }
        }
        return ok;
    }
}
