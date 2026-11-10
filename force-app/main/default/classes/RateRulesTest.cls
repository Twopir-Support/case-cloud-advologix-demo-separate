@IsTest
private class RateRulesTest {
    @IsTest
    static void ratesTimekeepersAndMattersAreProtected() {
        Account a = MatterTestDataFactory.account('Rate Rule Co');
        Matter__c m = MatterTestDataFactory.matter('Rate Rules', a.Id, null);
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('Rule TK', 100);
        Rate_Group__c g = new Rate_Group__c(Name = 'G');
        insert g;
        insert new Rate__c(Timekeeper__c = tk.Id, Matter__c = m.Id, Hourly_Rate__c = 100, Default__c = true);
        Assert.isFalse(Database.insert(new Rate__c(Timekeeper__c = tk.Id, Matter__c = m.Id, Hourly_Rate__c = 120, Default__c = true), false).isSuccess());
        Assert.isFalse(Database.insert(new List<Rate__c>{
            new Rate__c(Timekeeper__c = tk.Id, Rate_Group__c = g.Id, Hourly_Rate__c = 1, Default__c = true),
            new Rate__c(Timekeeper__c = tk.Id, Rate_Group__c = g.Id, Hourly_Rate__c = 2, Default__c = true) }, false)[1].isSuccess());
        insert new Rate__c(Timekeeper__c = tk.Id, Rate_Group__c = g.Id, Hourly_Rate__c = 90);
        Assert.isFalse(Database.delete(g, false).isSuccess());
        Assert.isFalse(Database.delete(tk, false).isSuccess());
        Assert.isFalse(Database.delete(m, false).isSuccess());
    }

    @IsTest
    static void createTimekeeperFromUser() {
        delete [SELECT Id FROM Timekeeper__c WHERE User__c = :UserInfo.getUserId()];
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), Create_Timekeeper__c = false);
            update new User(Id = UserInfo.getUserId(), Create_Timekeeper__c = true);
        }
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM Timekeeper__c WHERE User__c = :UserInfo.getUserId()]);
        TimekeeperService.createFor(new Set<Id>{ UserInfo.getUserId() });
        Assert.areEqual(1, [SELECT COUNT() FROM Timekeeper__c WHERE User__c = :UserInfo.getUserId()]);
    }
}
