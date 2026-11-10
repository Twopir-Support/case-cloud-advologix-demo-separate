// Removes ALL Matter Management records plus the sample Accounts and Contacts created by seed-1.
// Metadata (objects, Apex, app) is left in place.
List<Matter__c> held = [SELECT Id FROM Matter__c WHERE Legal_Hold__c = true];
for (Matter__c m : held) m.Legal_Hold__c = false;
update held;

List<Id> matterIds = new List<Id>(new Map<Id, Matter__c>([SELECT Id FROM Matter__c]).keySet());
delete [SELECT Id FROM Task WHERE WhatId IN :matterIds];
delete [SELECT Id FROM Activity_Plan__c];
delete [SELECT Id FROM Intake__c];
delete [SELECT Id FROM Conflict_Check__c];
delete [SELECT Id FROM Matter__c WHERE Parent_Matter__c != null];
delete [SELECT Id FROM Matter__c];          // cascades participants, time, expenses, budgets, invoices, holds
delete [SELECT Id FROM Rate__c];
delete [SELECT Id FROM Timekeeper__c];
delete [SELECT Id FROM Rate_Group__c];
delete [SELECT Id FROM Fee_Arrangement__c];
delete [SELECT Id FROM UTBMS_Code__c];
delete [SELECT Id FROM Activity_Plan_Template__c];
delete [SELECT Id FROM Contact WHERE Name IN ('Dana Whitfield','Priya Raman','Elena Calloway','Marcus Delgado','Tom Reyes','Grace Okafor','Jordan Pike','Nina Albright') AND Email LIKE '%@example.com'];
delete [SELECT Id FROM Account WHERE Name LIKE '% (Sample)'];
System.debug('Sample data removed.');
