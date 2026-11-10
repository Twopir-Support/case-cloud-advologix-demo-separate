@IsTest
private class ActionPlansUtilitiesExternalTest {

    @TestSetup
    static void setup() {
        Activity_Plan_Template__c t = new Activity_Plan_Template__c(Name = 'Litigation Test Plan', Type__c = 'Commercial Litigation', Active__c = true);
        insert t;
        insert new List<Activity_Plan_Template_Item__c>{
            new Activity_Plan_Template_Item__c(Activity_Plan_Template__c = t.Id, Step_Order__c = 1, Subject__c = 'Send engagement letter', Days_Offset__c = 1, Assign_To__c = 'Responsible Attorney', Priority__c = 'High'),
            new Activity_Plan_Template_Item__c(Activity_Plan_Template__c = t.Id, Step_Order__c = 2, Subject__c = 'Collect documents', Days_Offset__c = 7, Assign_To__c = 'Paralegal'),
            new Activity_Plan_Template_Item__c(Activity_Plan_Template__c = t.Id, Step_Order__c = 3, Subject__c = 'Calendar deadlines', Days_Offset__c = 3, Assign_To__c = 'Matter Owner')
        };
    }

    @IsTest
    static void appliesPlanByMatterType() {
        Account a = MatterTestDataFactory.account('Plan Test Co');
        Matter__c m = MatterTestDataFactory.matter('Plan Matter', a.Id, null);
        update new Matter__c(Id = m.Id, Paralegal__c = UserInfo.getUserId());
        Test.startTest();
        Integer created = ActionPlansUtilitiesExternal.applyDefaultPlan(m.Id);
        Test.stopTest();
        Assert.areEqual(3, created);
        Task first = [SELECT ActivityDate, Priority FROM Task WHERE WhatId = :m.Id AND Subject = 'Send engagement letter'];
        Assert.areEqual(Date.today().addDays(1), first.ActivityDate);
        Assert.areEqual('High', first.Priority);
        Activity_Plan__c plan = [SELECT Name, Number_of_Tasks__c FROM Activity_Plan__c WHERE Matter__c = :m.Id];
        Assert.areEqual('Litigation Test Plan', plan.Name);
        Assert.areEqual(3, plan.Number_of_Tasks__c);
    }

    @IsTest
    static void applyActionPlanApiOnAccountsAndContacts() {
        Account a = MatterTestDataFactory.account('Plan Test Co 2');
        Contact c = MatterTestDataFactory.contact('Ana', 'Plan', a.Id);
        Id templateId = [SELECT Id FROM Activity_Plan_Template__c LIMIT 1].Id;
        Map<String, Object> res = (Map<String, Object>) JSON.deserializeUntyped(
            ActionPlansUtilitiesExternal.ApplyActionPlan('Onboarding', templateId, a.Id, 'Account'));
        Assert.areEqual(true, res.get('success'));
        Assert.areEqual(3, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id]);
        res = (Map<String, Object>) JSON.deserializeUntyped(
            ActionPlansUtilitiesExternal.ApplyActionPlan('Onboarding', templateId, c.Id, 'Contact'));
        Assert.areEqual(true, res.get('success'));
        Assert.areEqual(3, [SELECT COUNT() FROM Task WHERE WhoId = :c.Id]);
    }

    @IsTest
    static void applyActionPlanApiReportsErrors() {
        Id templateId = [SELECT Id FROM Activity_Plan_Template__c LIMIT 1].Id;
        Map<String, Object> res = (Map<String, Object>) JSON.deserializeUntyped(
            ActionPlansUtilitiesExternal.ApplyActionPlan('Bad', templateId, UserInfo.getUserId(), 'User'));
        Assert.areEqual(false, res.get('success'));
        Assert.areEqual(0, [SELECT COUNT() FROM Activity_Plan__c]);
    }

    @IsTest
    static void appliesExplicitTemplateFromFlow() {
        Account a = MatterTestDataFactory.account('Plan Test Co 3');
        Matter__c m = new Matter__c(Name = 'Family', Primary_Account__c = a.Id, Type__c = 'Family Law');
        insert m;
        ActionPlansUtilitiesExternal.Request req = new ActionPlansUtilitiesExternal.Request();
        req.recordId = m.Id;
        req.templateId = [SELECT Id FROM Activity_Plan_Template__c LIMIT 1].Id;
        Assert.areEqual(3, ActionPlansUtilitiesExternal.applyFromFlow(new List<ActionPlansUtilitiesExternal.Request>{ req })[0]);
    }

    @IsTest
    static void errorsWhenNoTemplate() {
        Matter__c m = new Matter__c(Name = 'Immigration', Type__c = 'Immigration');
        insert m;
        try {
            ActionPlansUtilitiesExternal.applyDefaultPlan(m.Id);
            Assert.fail('Expected an error');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('no active activity plan'));
        }
    }

    @IsTest
    static void errorsWhenTemplateEmptyOrMissing() {
        Activity_Plan_Template__c empty = new Activity_Plan_Template__c(Name = 'Empty', Type__c = 'Real Estate', Active__c = true);
        insert empty;
        Matter__c m = new Matter__c(Name = 'RE', Type__c = 'Real Estate');
        insert m;
        try {
            ActionPlansUtilitiesExternal.apply(null, empty.Id, m.Id);
            Assert.fail('Expected an error');
        } catch (ActionPlansUtilitiesExternal.PlanException e) {
            Assert.isTrue(e.getMessage().contains('no items'));
        }
        Account a = MatterTestDataFactory.account('No Template Co');
        try {
            ActionPlansUtilitiesExternal.apply(null, null, a.Id);
            Assert.fail('Expected an error');
        } catch (ActionPlansUtilitiesExternal.PlanException e) {
            Assert.isTrue(e.getMessage().contains('Choose an activity plan template'));
        }
    }
}
