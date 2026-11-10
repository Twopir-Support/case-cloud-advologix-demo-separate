/** Focus Matters: each user's pinned matters. */
public with sharing class FocusMatterService {

    public class FocusRow {
        @AuraEnabled public Id matterId;
        @AuraEnabled public String name;
        @AuraEnabled public String matterNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String stage;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal unbilled;
        @AuraEnabled public String nextTask;
        @AuraEnabled public Date nextTaskDate;
        @AuraEnabled public Boolean overdue;
    }

    /** Adds the matter to the current user's Focus Matters, or removes it. Returns true when it is now a focus matter. */
    @AuraEnabled
    public static Boolean toggle(Id matterId) {
        String key = String.valueOf(UserInfo.getUserId()) + String.valueOf(matterId);
        List<Focus_Matter__c> existing = [SELECT Id FROM Focus_Matter__c WHERE Unique_Key__c = :key];
        if (!existing.isEmpty()) {
            delete existing;
            return false;
        }
        insert new Focus_Matter__c(Matter__c = matterId, User__c = UserInfo.getUserId(), Unique_Key__c = key);
        return true;
    }

    @AuraEnabled
    public static List<FocusRow> getMyFocusMatters() {
        List<Focus_Matter__c> focus = [
            SELECT Matter__c, Matter__r.Name, Matter__r.Matter_Number__c, Matter__r.Status__c, Matter__r.Stage__c, Matter__r.Type__c,
                   Matter__r.Unbilled_Time_Value__c, Matter__r.Unbilled_Expenses__c
            FROM Focus_Matter__c WHERE User__c = :UserInfo.getUserId() ORDER BY Matter__r.Name LIMIT 100];
        Set<Id> matterIds = new Set<Id>();
        for (Focus_Matter__c f : focus) {
            matterIds.add(f.Matter__c);
        }
        Map<Id, Task> nextTask = new Map<Id, Task>();
        for (Task t : [SELECT WhatId, Subject, ActivityDate FROM Task WHERE WhatId IN :matterIds AND IsClosed = false
                       ORDER BY ActivityDate ASC NULLS LAST LIMIT 1000]) {
            if (!nextTask.containsKey(t.WhatId)) {
                nextTask.put(t.WhatId, t);
            }
        }
        List<FocusRow> rows = new List<FocusRow>();
        for (Focus_Matter__c f : focus) {
            FocusRow r = new FocusRow();
            r.matterId = f.Matter__c;
            r.name = f.Matter__r.Name;
            r.matterNumber = f.Matter__r.Matter_Number__c;
            r.status = f.Matter__r.Status__c;
            r.stage = f.Matter__r.Stage__c;
            r.type = f.Matter__r.Type__c;
            r.unbilled = (f.Matter__r.Unbilled_Time_Value__c == null ? 0 : f.Matter__r.Unbilled_Time_Value__c)
                + (f.Matter__r.Unbilled_Expenses__c == null ? 0 : f.Matter__r.Unbilled_Expenses__c);
            Task t = nextTask.get(f.Matter__c);
            if (t != null) {
                r.nextTask = t.Subject;
                r.nextTaskDate = t.ActivityDate;
                r.overdue = t.ActivityDate != null && t.ActivityDate < Date.today();
            }
            rows.add(r);
        }
        return rows;
    }
}
