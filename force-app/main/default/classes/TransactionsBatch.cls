/** Nightly rebuild of Transactions. Schedule: System.schedule('Matter Management Transactions', '0 0 0 * * ?', new TransactionsBatch()); */
public with sharing class TransactionsBatch implements Database.Batchable<SObject>, Schedulable {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM Matter__c]);
    }
    public void execute(Database.BatchableContext bc, List<Matter__c> scope) {
        TransactionService.rebuild(new Map<Id, Matter__c>(scope).keySet());
    }
    public void finish(Database.BatchableContext bc) {
        delete [SELECT Id FROM Transaction__c WHERE Matter__c = null LIMIT 9000];
    }
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TransactionsBatch(), 50);
    }
}
