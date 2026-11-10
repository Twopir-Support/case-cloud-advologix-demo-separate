@IsTest
private class MatterStatusRuleBatchTest {
    @IsTest
    static void rulesCloseMatchingMatters() {
        Account a = MatterTestDataFactory.account('Rule Co');
        Matter__c old = new Matter__c(Name = 'Old settled', Primary_Account__c = a.Id, Status__c = 'Settled', Open_Date__c = Date.today().addDays(-90));
        Matter__c fresh = new Matter__c(Name = 'New settled', Primary_Account__c = a.Id, Status__c = 'Settled', Open_Date__c = Date.today());
        Matter__c held = new Matter__c(Name = 'Held', Primary_Account__c = a.Id, Status__c = 'Settled', Open_Date__c = Date.today().addDays(-90), Legal_Hold__c = true);
        insert new List<Matter__c>{ old, fresh, held };
        MatterStatusRuleBatch.testRules = new List<Matter_Status_Rule__mdt>{ (Matter_Status_Rule__mdt) JSON.deserialize(
            '{"Target_Status__c":"Closed","Field_1__c":"Status__c","Operator_1__c":"equals","Value_1__c":"Settled",'
            + '"Field_2__c":"Open_Date__c","Operator_2__c":"older than days","Value_2__c":"30"}', Matter_Status_Rule__mdt.class) };
        Assert.areEqual(1, MatterStatusRuleBatch.runFromFlow(new List<String>())[0]);
        Assert.areEqual('Closed', [SELECT Status__c FROM Matter__c WHERE Id = :old.Id].Status__c);
        Assert.areEqual('Settled', [SELECT Status__c FROM Matter__c WHERE Id = :fresh.Id].Status__c);
        Assert.areEqual('Settled', [SELECT Status__c FROM Matter__c WHERE Id = :held.Id].Status__c);
        Test.startTest();
        new MatterStatusRuleBatch().execute(null);
        Test.stopTest();
    }

    @IsTest
    static void conditionTypes() {
        Map<String, Object> b = new Map<String, Object>();
        Assert.areEqual(' AND Legal_Hold__c = :k', MatterStatusRuleBatch.condition('Legal_Hold__c', 'equals', 'false', b, 'k'));
        Assert.areEqual(' AND Total_Hours__c > :k', MatterStatusRuleBatch.condition('Total_Hours__c', 'greater than', '5', b, 'k'));
        Assert.areEqual(' AND Close_Date__c < :k', MatterStatusRuleBatch.condition('Close_Date__c', 'less than', '2026-01-01', b, 'k'));
        Assert.areEqual(' AND CreatedDate != :k', MatterStatusRuleBatch.condition('CreatedDate', 'not equal to', '2026-01-01 00:00:00', b, 'k'));
        Assert.areEqual(' AND CreatedDate < :k', MatterStatusRuleBatch.condition('CreatedDate', 'older than days', '5', b, 'k'));
        Assert.areEqual(' AND Close_Date__c = null', MatterStatusRuleBatch.condition('Close_Date__c', 'is blank', null, b, 'k'));
        Assert.areEqual(' AND Close_Date__c != null', MatterStatusRuleBatch.condition('Close_Date__c', 'is not blank', null, b, 'k'));
        Assert.areEqual('', MatterStatusRuleBatch.condition(null, null, null, b, 'k'));
        try { MatterStatusRuleBatch.condition('Nope__c', 'equals', 'x', b, 'k'); Assert.fail(); } catch (MatterStatusRuleBatch.RuleException e) { Assert.isNotNull(e); }
        try { MatterStatusRuleBatch.condition('Name', 'like', 'x', b, 'k'); Assert.fail(); } catch (MatterStatusRuleBatch.RuleException e) { Assert.isNotNull(e); }
    }
}
