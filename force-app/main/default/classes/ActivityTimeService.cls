/**
 * Task and Event automation:
 *  - Log Time: an activity on a Matter with "Time in Hours" creates or updates a Time record
 *    (timekeeper = activity owner) and stores its Id in Time Record Id.
 *  - Activity plan dependencies: moving a plan task's due date re-dates the tasks that depend on it.
 */
public with sharing class ActivityTimeService {
    private static Boolean writingBack = false;

    public static void afterSave(List<SObject> rows, Map<Id, SObject> oldMap) {
        if (writingBack) {
            return;
        }
        logTime(rows, oldMap);
        if (oldMap != null) {
            redateDependents(rows, oldMap);
        }
    }

    private static void logTime(List<SObject> rows, Map<Id, SObject> oldMap) {
        List<SObject> candidates = new List<SObject>();
        Set<Id> ownerIds = new Set<Id>();
        for (SObject r : rows) {
            Id whatId = (Id) r.get('WhatId');
            Decimal hours = (Decimal) r.get('Time_in_Hours__c');
            if (whatId == null || whatId.getSObjectType() != Matter__c.SObjectType || hours == null || hours <= 0) {
                continue;
            }
            if (oldMap != null) {
                SObject o = oldMap.get(r.Id);
                if (r.get('Time_Record_Id__c') != null && o.get('Time_in_Hours__c') == hours
                        && o.get('Subject') == r.get('Subject') && o.get('ActivityDate') == r.get('ActivityDate')) {
                    continue;
                }
            }
            candidates.add(r);
            ownerIds.add((Id) r.get('OwnerId'));
        }
        if (candidates.isEmpty()) {
            return;
        }
        Map<Id, Id> tkByUser = new Map<Id, Id>();
        for (Timekeeper__c t : [SELECT Id, User__c FROM Timekeeper__c WHERE User__c IN :ownerIds AND Active__c = true ORDER BY CreatedDate]) {
            if (!tkByUser.containsKey(t.User__c)) {
                tkByUser.put(t.User__c, t.Id);
            }
        }
        List<Time__c> times = new List<Time__c>();
        List<SObject> sources = new List<SObject>();
        for (SObject r : candidates) {
            Id tk = tkByUser.get((Id) r.get('OwnerId'));
            if (tk == null) {
                continue;
            }
            String narrative = (String) r.get('Subject');
            if (r.get('Description') != null) {
                narrative += '\n' + (String) r.get('Description');
            }
            Date d = (Date) r.get('ActivityDate');
            String existing = (String) r.get('Time_Record_Id__c');
            Time__c t = existing != null ? new Time__c(Id = existing) : new Time__c(Matter__c = (Id) r.get('WhatId'), Name = 'Time', Source_Activity_Id__c = r.Id);
            t.Timekeeper__c = tk;
            t.Entry_Date__c = d == null ? Date.today() : d;
            t.Time_in_Hours__c = (Decimal) r.get('Time_in_Hours__c');
            t.Narrative__c = narrative;
            times.add(t);
            sources.add(r);
        }
        List<SObject> writeBack = new List<SObject>();
        List<Database.UpsertResult> results = Database.upsert(times, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess() && results[i].isCreated()) {
                SObject back = sources[i].getSObjectType().newSObject(sources[i].Id);
                back.put('Time_Record_Id__c', results[i].getId());
                writeBack.add(back);
            } else if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.WARN, 'Log Time skipped: ' + results[i].getErrors()[0].getMessage());
            }
        }
        if (!writeBack.isEmpty()) {
            writingBack = true;
            try {
                update writeBack;
            } finally {
                writingBack = false;
            }
        }
    }

    private static void redateDependents(List<SObject> rows, Map<Id, SObject> oldMap) {
        if (rows.isEmpty() || rows[0].getSObjectType() != Task.SObjectType) {
            return;
        }
        Map<String, Date> movedByPlanItem = new Map<String, Date>();
        Set<String> itemIds = new Set<String>();
        Set<String> planIds = new Set<String>();
        for (SObject r : rows) {
            String item = (String) r.get('Activity_Plan_Item_Id__c');
            String plan = (String) r.get('Activity_Plan_Id__c');
            Date newDate = (Date) r.get('ActivityDate');
            if (item == null || plan == null || newDate == null || newDate == (Date) oldMap.get(r.Id).get('ActivityDate')) {
                continue;
            }
            movedByPlanItem.put(plan + '|' + item, newDate);
            itemIds.add(item);
            planIds.add(plan);
        }
        if (movedByPlanItem.isEmpty()) {
            return;
        }
        Map<String, Activity_Plan_Template_Item__c> dependents = new Map<String, Activity_Plan_Template_Item__c>();
        for (Activity_Plan_Template_Item__c d : [SELECT Id, Depends_On__c, Days_After_Dependency__c FROM Activity_Plan_Template_Item__c WHERE Depends_On__c IN :itemIds]) {
            dependents.put(String.valueOf(d.Id), d);
        }
        if (dependents.isEmpty()) {
            return;
        }
        List<Task> toUpdate = new List<Task>();
        for (Task t : [SELECT Id, ActivityDate, Activity_Plan_Id__c, Activity_Plan_Item_Id__c FROM Task
                       WHERE Activity_Plan_Id__c IN :planIds AND Activity_Plan_Item_Id__c IN :dependents.keySet() AND IsClosed = false]) {
            Activity_Plan_Template_Item__c d = dependents.get(t.Activity_Plan_Item_Id__c);
            Date parentDate = movedByPlanItem.get(t.Activity_Plan_Id__c + '|' + String.valueOf(d.Depends_On__c));
            if (parentDate != null) {
                Date target = parentDate.addDays(d.Days_After_Dependency__c == null ? 0 : d.Days_After_Dependency__c.intValue());
                if (t.ActivityDate != target) {
                    toUpdate.add(new Task(Id = t.Id, ActivityDate = target));
                }
            }
        }
        update toUpdate;
    }
}
