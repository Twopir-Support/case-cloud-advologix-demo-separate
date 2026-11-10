@IsTest
private class RatesServiceTest {

    @IsTest
    static void copiesFromGroupMatterAndBoth() {
        Account a = MatterTestDataFactory.account('Rates Copy Co');
        Matter__c source = MatterTestDataFactory.matter('Source', a.Id, null);
        Matter__c target = MatterTestDataFactory.matter('Target', a.Id, null);
        Matter__c target2 = MatterTestDataFactory.matter('Target 2', a.Id, null);
        Rate_Group__c g = new Rate_Group__c(Name = 'Panel');
        insert g;
        Timekeeper__c tk1 = MatterTestDataFactory.timekeeper('TK One', 300);
        Timekeeper__c tk2 = MatterTestDataFactory.timekeeper('TK Two', 200);
        insert new List<Rate__c>{
            new Rate__c(Timekeeper__c = tk1.Id, Rate_Group__c = g.Id, Hourly_Rate__c = 280, Default__c = true),
            new Rate__c(Timekeeper__c = tk2.Id, Rate_Group__c = g.Id, Hourly_Rate__c = 180),
            new Rate__c(Timekeeper__c = tk1.Id, Matter__c = source.Id, Hourly_Rate__c = 250)
        };

        Map<String, Object> res = (Map<String, Object>) JSON.deserializeUntyped(RatesService.copyRates(null, g.Id, target.Id, true));
        Assert.areEqual(true, res.get('success'));
        Assert.areEqual(2, [SELECT COUNT() FROM Rate__c WHERE Matter__c = :target.Id]);
        Assert.areEqual(1, [SELECT COUNT() FROM Rate__c WHERE Matter__c = :target.Id AND Default__c = true]);

        RatesService.Request req = new RatesService.Request();
        req.fromMatterId = source.Id;
        req.fromRateGroupId = g.Id;
        req.toMatterId = target2.Id;
        RatesService.copyFromFlow(new List<RatesService.Request>{ req });
        Rate__c copied = [SELECT Hourly_Rate__c, Default__c FROM Rate__c WHERE Matter__c = :target2.Id];
        Assert.areEqual(250, copied.Hourly_Rate__c);
        Assert.isFalse(copied.Default__c);
    }

    @IsTest
    static void reportsMissingArguments() {
        Map<String, Object> res = (Map<String, Object>) JSON.deserializeUntyped(RatesService.copyRates(null, null, null, false));
        Assert.areEqual(false, res.get('success'));
        Account a = MatterTestDataFactory.account('Rates Copy Co 2');
        Matter__c target = MatterTestDataFactory.matter('Target', a.Id, null);
        res = (Map<String, Object>) JSON.deserializeUntyped(RatesService.copyRates(null, null, target.Id, false));
        Assert.areEqual(false, res.get('success'));
        Assert.isTrue(((String) res.get('result')).contains('From Matter ID'));
    }
}
