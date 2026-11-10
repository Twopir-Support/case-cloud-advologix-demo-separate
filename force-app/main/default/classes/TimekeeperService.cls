/** Creates a Timekeeper for users whose "Create Timekeeper" box is ticked. */
public with sharing class TimekeeperService {

    public static void onUsersSaved(List<User> users, Map<Id, User> oldMap) {
        Set<Id> ids = new Set<Id>();
        for (User u : users) {
            Boolean was = oldMap != null && oldMap.get(u.Id).Create_Timekeeper__c;
            if (u.Create_Timekeeper__c && !was) {
                ids.add(u.Id);
            }
        }
        if (ids.isEmpty()) {
            return;
        }
        if (System.isFuture() || System.isBatch()) {
            createFor(ids);
        } else {
            createAsync(ids);   // avoids mixed DML (User is a setup object)
        }
    }

    @future
    public static void createAsync(Set<Id> userIds) {
        createFor(userIds);
    }

    public static void createFor(Set<Id> userIds) {
        Set<Id> existing = new Set<Id>();
        for (Timekeeper__c t : [SELECT User__c FROM Timekeeper__c WHERE User__c IN :userIds]) {
            existing.add(t.User__c);
        }
        List<Timekeeper__c> tks = new List<Timekeeper__c>();
        for (User u : [SELECT Id, Name, Email FROM User WHERE Id IN :userIds]) {
            if (!existing.contains(u.Id)) {
                tks.add(new Timekeeper__c(Name = u.Name, User__c = u.Id, Email__c = u.Email, Active__c = true));
            }
        }
        insert tks;
    }
}
