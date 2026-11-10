@IsTest
private class ConflictSearchServiceTest {

    @TestSetup
    static void setup() {
        // Existing matter: Qyntaro is our client, Velmorrix is the opposing party.
        Account client = MatterTestDataFactory.account('Qyntaro Test Freight');
        Account opposing = MatterTestDataFactory.account('Velmorrix Test Industries');
        Matter__c m = MatterTestDataFactory.matter('Qyntaro v Velmorrix', client.Id, null);
        insert new List<Participant__c>{
            new Participant__c(Matter__c = m.Id, Account__c = opposing.Id, Role__c = 'Opposing Party'),
            new Participant__c(Matter__c = m.Id, Other_Name__c = 'Dorvane Test Expert', Role__c = 'Expert Witness')
        };
    }

    @IsTest
    static void newClientWhoIsOpposingPartyIsFlagged() {
        Intake__c i = new Intake__c(Name = 'Velmorrix Test Industries', Status__c = 'Requested');
        insert i;
        Test.startTest();
        ConflictSearchService.ResultWrapper r = ConflictSearchService.runForIntake(i.Id);
        Test.stopTest();
        Assert.areEqual('TRUE', r.status);
        Assert.areEqual('Potential Conflict', r.conflictStatus);
        Assert.areEqual(1, r.results);
        Intake__c after = [SELECT Status__c, Conflict_Status__c FROM Intake__c WHERE Id = :i.Id];
        Assert.areEqual('Potential Conflict', after.Conflict_Status__c);
        Assert.areEqual('In Progress', after.Status__c);
    }

    @IsTest
    static void existingClientOnlyIsClear() {
        Account client = [SELECT Id FROM Account WHERE Name = 'Qyntaro Test Freight'];
        Intake__c i = new Intake__c(Name = 'Qyntaro Test Freight', Primary_Account__c = client.Id);
        insert i;
        ConflictSearchService.ResultWrapper r = ConflictSearchService.checkIntake(i.Id);
        Assert.areEqual('Clear', r.conflictStatus);
        Assert.areEqual('Not a Conflict', [SELECT Resolution__c FROM Conflict_Check_Result__c LIMIT 1].Resolution__c);
    }

    @IsTest
    static void executeSearchWithContextRecord() {
        Intake__c i = new Intake__c(Name = 'xy');
        insert i;
        ConflictSearchService.InputWrapper input = new ConflictSearchService.InputWrapper();
        input.searchTerm = '(Dorvane OR Nobody) AND xy';
        input.description = 'Expert check';
        input.contextRecordId = i.Id;
        List<ConflictSearchService.ResultWrapper> rs = ConflictSearchService.executeSearch(new List<ConflictSearchService.InputWrapper>{ input });
        Assert.areEqual('TRUE', rs[0].status);
        Conflict_Check__c c = [SELECT Status__c, Hit_Count__c, Intake__c, Description__c FROM Conflict_Check__c WHERE Id = :rs[0].conflictCheckId];
        Assert.areEqual('Potential Conflict', c.Status__c);
        Assert.areEqual(1, c.Hit_Count__c);
        Assert.areEqual(i.Id, c.Intake__c);
        Assert.areEqual('Expert check', c.Description__c);
    }

    @IsTest
    static void executeSearchRejectsEmptyTerm() {
        ConflictSearchService.InputWrapper input = new ConflictSearchService.InputWrapper();
        input.searchTerm = 'ab';
        ConflictSearchService.ResultWrapper r = ConflictSearchService.executeSearch(new List<ConflictSearchService.InputWrapper>{ input })[0];
        Assert.areEqual('FALSE', r.status);
        Assert.isTrue(r.body.contains('at least 3 characters'));
    }

    @IsTest
    static void runBatchLimitsToTwenty() {
        List<ConflictSearchService.InputWrapper> many = new List<ConflictSearchService.InputWrapper>();
        for (Integer i = 0; i < 21; i++) {
            ConflictSearchService.InputWrapper w = new ConflictSearchService.InputWrapper();
            w.searchTerm = 'Name ' + i;
            many.add(w);
        }
        try {
            ConflictSearchService.runBatch(many);
            Assert.fail('Expected limit error');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('20 names'));
        }
        many.remove(20);
        many.remove(19);
        Assert.areEqual(19, ConflictSearchService.runBatch(many).size());
    }

    @IsTest
    static void emptyIntakeIsRejected() {
        Intake__c i = new Intake__c(Name = 'ab');
        insert i;
        try {
            ConflictSearchService.runForIntake(i.Id);
            Assert.fail('Expected an error');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('before running a conflict check'));
        }
    }
}
