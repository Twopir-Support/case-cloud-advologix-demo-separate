/**
 * Time entry and expense automation:
 *  - default entry date and the matter's default fee / expense arrangement
 *  - resolve the hourly rate: matter rate -> matter's rate group -> timekeeper default
 *  - lock billed records against edits, block deletes of billed or legal-hold records
 */
public with sharing class BillableTriggerHandler {
    public static final String EXPORTED_MESSAGE = 'This time has been exported. Clear the Exported box before changing it.';
    public static final String BILLED_MESSAGE = 'This record has been billed. Void the invoice before changing it.';

    public static void timeBeforeSave(List<Time__c> rows, Map<Id, Time__c> oldMap) {
        Set<Id> matterIds = new Set<Id>();
        Set<Id> timekeeperIds = new Set<Id>();
        for (Time__c t : rows) {
            if (t.Entry_Date__c == null) {
                t.Entry_Date__c = Date.today();
            }
            matterIds.add(t.Matter__c);
            if (t.Timekeeper__c != null) {
                timekeeperIds.add(t.Timekeeper__c);
            }
            if (oldMap != null) {
                Time__c old = oldMap.get(t.Id);
                Boolean stillBilled = old.Status__c == 'Billed' && t.Status__c == 'Billed';
                Boolean coreChanged = t.Time_in_Hours__c != old.Time_in_Hours__c || t.Rate__c != old.Rate__c
                        || t.Disposition__c != old.Disposition__c || t.Timekeeper__c != old.Timekeeper__c;
                if (stillBilled && coreChanged) {
                    t.addError(BILLED_MESSAGE);
                } else if (old.Exported__c && t.Exported__c && (coreChanged || t.Entry_Date__c != old.Entry_Date__c)) {
                    t.addError(EXPORTED_MESSAGE);
                }
            }
            if (t.Disposition__c == 'Do Not Bill') {
                t.Billable__c = false;
            }
        }
        Map<Id, Id> defaultFees = defaultArrangements(matterIds, true);
        Map<Id, Matter__c> matters = new Map<Id, Matter__c>(
            [SELECT Id, Name, Rate_Group__c FROM Matter__c WHERE Id IN :matterIds]);
        Set<Id> groupIds = new Set<Id>();
        for (Matter__c m : matters.values()) {
            if (m.Rate_Group__c != null) {
                groupIds.add(m.Rate_Group__c);
            }
        }
        List<Rate__c> rates = timekeeperIds.isEmpty() ? new List<Rate__c>() : [
            SELECT Timekeeper__c, Matter__c, Rate_Group__c, Hourly_Rate__c, Effective_Date__c
            FROM Rate__c
            WHERE Timekeeper__c IN :timekeeperIds AND (Matter__c IN :matterIds OR Rate_Group__c IN :groupIds)
            ORDER BY Effective_Date__c DESC NULLS LAST
        ];
        Map<Id, Timekeeper__c> timekeepers = new Map<Id, Timekeeper__c>(
            [SELECT Id, Default_Rate__c FROM Timekeeper__c WHERE Id IN :timekeeperIds]);

        for (Time__c t : rows) {
            if (t.Matter_Fee_Arrangement__c == null) {
                t.Matter_Fee_Arrangement__c = defaultFees.get(t.Matter__c);
            }
            Matter__c owningMatter = matters.get(t.Matter__c);
            if (owningMatter != null && t.Entry_Date__c != null) {
                // Name pattern "yyyy-mm-dd : Matter Name", first 80 characters
                t.Name = (String.valueOf(t.Entry_Date__c) + ' : ' + owningMatter.Name).left(80);
            }
            if (t.Rate__c == null && t.Timekeeper__c != null) {
                Matter__c m = matters.get(t.Matter__c);
                t.Rate__c = resolveRate(t, m == null ? null : m.Rate_Group__c, rates, timekeepers.get(t.Timekeeper__c));
            }
        }
        fillSourceArrangements(rows);
    }

    private static void fillSourceArrangements(List<SObject> rows) {
        Set<Id> mfaIds = new Set<Id>();
        for (SObject r : rows) {
            Id mfa = (Id) r.get('Matter_Fee_Arrangement__c');
            if (mfa != null) {
                mfaIds.add(mfa);
            }
        }
        if (mfaIds.isEmpty()) {
            return;
        }
        Map<Id, Matter_Fee_Arrangement__c> mfas = new Map<Id, Matter_Fee_Arrangement__c>(
            [SELECT Id, Source_Fee_Arrangement__c FROM Matter_Fee_Arrangement__c WHERE Id IN :mfaIds]);
        for (SObject r : rows) {
            Matter_Fee_Arrangement__c mfa = mfas.get((Id) r.get('Matter_Fee_Arrangement__c'));
            if (mfa != null && r.get('Source_Fee_Arrangement__c') == null) {
                r.put('Source_Fee_Arrangement__c', mfa.Source_Fee_Arrangement__c);
            }
        }
    }

    @TestVisible
    private static Decimal resolveRate(Time__c t, Id rateGroupId, List<Rate__c> rates, Timekeeper__c tk) {
        Rate__c groupRate;
        for (Rate__c r : rates) {
            if (r.Timekeeper__c != t.Timekeeper__c) {
                continue;
            }
            if (r.Effective_Date__c != null && r.Effective_Date__c > t.Entry_Date__c) {
                continue;
            }
            if (r.Matter__c == t.Matter__c) {
                return r.Hourly_Rate__c;
            }
            if (groupRate == null && rateGroupId != null && r.Rate_Group__c == rateGroupId && r.Matter__c == null) {
                groupRate = r;
            }
        }
        if (groupRate != null) {
            return groupRate.Hourly_Rate__c;
        }
        return tk == null ? null : tk.Default_Rate__c;
    }

    public static void expenseBeforeSave(List<Expense__c> rows, Map<Id, Expense__c> oldMap) {
        Set<Id> matterIds = new Set<Id>();
        for (Expense__c e : rows) {
            if (e.Expense_Date__c == null) {
                e.Expense_Date__c = Date.today();
            }
            matterIds.add(e.Matter__c);
            if (oldMap != null) {
                Expense__c old = oldMap.get(e.Id);
                if (old.Status__c == 'Billed' && e.Status__c == 'Billed'
                        && (e.Amount__c != old.Amount__c || e.Disposition__c != old.Disposition__c)) {
                    e.addError(BILLED_MESSAGE);
                }
            }
            if (e.Disposition__c == 'Do Not Bill') {
                e.Billable__c = false;
            }
        }
        Map<Id, Id> defaultExpenses = defaultArrangements(matterIds, false);
        for (Expense__c e : rows) {
            if (e.Matter_Fee_Arrangement__c == null) {
                e.Matter_Fee_Arrangement__c = defaultExpenses.get(e.Matter__c);
            }
        }
        fillSourceArrangements(rows);
    }

    public static void beforeDelete(List<SObject> rows) {
        for (SObject r : rows) {
            if (r.getSObjectType() == Time__c.SObjectType && r.get('Exported__c') == true) {
                r.addError(EXPORTED_MESSAGE);
            }
            if (r.get('Status__c') == 'Billed') {
                r.addError(BILLED_MESSAGE);
            }
        }
        LegalHoldGuard.blockDeletes(rows, 'Matter__c');
    }

    private static Map<Id, Id> defaultArrangements(Set<Id> matterIds, Boolean forFees) {
        Map<Id, Id> result = new Map<Id, Id>();
        for (Matter_Fee_Arrangement__c a : [
            SELECT Id, Matter__c, Default_for_Fees__c, Default_for_Expenses__c
            FROM Matter_Fee_Arrangement__c
            WHERE Matter__c IN :matterIds
            ORDER BY CreatedDate
        ]) {
            Boolean isDefault = forFees ? a.Default_for_Fees__c : a.Default_for_Expenses__c;
            if (isDefault && !result.containsKey(a.Matter__c)) {
                result.put(a.Matter__c, a.Id);
            }
        }
        return result;
    }
}
