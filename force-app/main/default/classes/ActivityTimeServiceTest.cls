@IsTest
private class ActivityTimeServiceTest {
    @IsTest
    static void tasksAndEventsLogTime() {
        Account a = MatterTestDataFactory.account('Log Co');
        Matter__c m = MatterTestDataFactory.matter('Log Matter', a.Id, null);
        MatterTestDataFactory.timekeeper('Me', 200);
        Task t = new Task(WhatId = m.Id, Subject = 'Call client', ActivityDate = Date.today(), Time_in_Hours__c = 0.5, Description = 'Status call');
        insert t;
        t = [SELECT Time_Record_Id__c FROM Task WHERE Id = :t.Id];
        Assert.isNotNull(t.Time_Record_Id__c);
        Time__c tm = [SELECT Time_in_Hours__c, Rate__c FROM Time__c WHERE Id = :t.Time_Record_Id__c];
        Assert.areEqual(0.5, tm.Time_in_Hours__c);
        Assert.areEqual(200, tm.Rate__c);
        update new Task(Id = t.Id, Time_in_Hours__c = 1.5);
        Assert.areEqual(1.5, [SELECT Time_in_Hours__c FROM Time__c WHERE Id = :t.Time_Record_Id__c].Time_in_Hours__c);
        insert new Event(WhatId = m.Id, Subject = 'Hearing', StartDateTime = System.now(), EndDateTime = System.now().addHours(2), Time_in_Hours__c = 2);
        Assert.areEqual(2, [SELECT COUNT() FROM Time__c WHERE Matter__c = :m.Id]);
    }

    @IsTest
    static void dependentTasksAreRedated() {
        Activity_Plan_Template__c tpl = new Activity_Plan_Template__c(Name = 'Dep', Type__c = 'Commercial Litigation', Active__c = true);
        insert tpl;
        Activity_Plan_Template_Item__c first = new Activity_Plan_Template_Item__c(Activity_Plan_Template__c = tpl.Id, Step_Order__c = 1, Subject__c = 'File complaint', Days_Offset__c = 5);
        insert first;
        insert new Activity_Plan_Template_Item__c(Activity_Plan_Template__c = tpl.Id, Step_Order__c = 2, Subject__c = 'Serve defendant', Depends_On__c = first.Id, Days_After_Dependency__c = 3);
        Account a = MatterTestDataFactory.account('Dep Co');
        Matter__c m = MatterTestDataFactory.matter('Dep Matter', a.Id, null);
        ActionPlansUtilitiesExternal.applyDefaultPlan(m.Id);
        Task filing = [SELECT Id, ActivityDate FROM Task WHERE WhatId = :m.Id AND Subject = 'File complaint'];
        Assert.areEqual(Date.today().addDays(8), [SELECT ActivityDate FROM Task WHERE WhatId = :m.Id AND Subject = 'Serve defendant'].ActivityDate);
        update new Task(Id = filing.Id, ActivityDate = filing.ActivityDate.addDays(10));
        Assert.areEqual(Date.today().addDays(18), [SELECT ActivityDate FROM Task WHERE WhatId = :m.Id AND Subject = 'Serve defendant'].ActivityDate);
    }
}
