@IsTest
private class IntakeServiceTest {

    private static Intake__c newIntake(String status, String conflict) {
        Account a = MatterTestDataFactory.account('Zephyrine Test Holdings');
        Contact c = MatterTestDataFactory.contact('Ilsa', 'Quorvant', a.Id);
        Intake__c i = new Intake__c(Name = 'Zephyrine Test Holdings', Type__c = 'Employment',
            Primary_Account__c = a.Id, Primary_Contact__c = c.Id, Adverse_Party__c = 'Brackmoor Test Partners',
            Status__c = status, Conflict_Status__c = conflict, Approver__c = UserInfo.getUserId());
        insert i;
        return i;
    }

    @IsTest
    static void convertsApprovedIntake() {
        Intake__c i = newIntake('Approved', 'Clear');
        insert new Conflict_Check__c(Intake__c = i.Id, Status__c = 'Clear', Search_Term__c = 'x');

        Test.startTest();
        Id matterId = IntakeService.convertIntake(i.Id);
        Test.stopTest();

        Matter__c m = [SELECT Name, Status__c, Primary_Account__c, Responsible_Attorney__c FROM Matter__c WHERE Id = :matterId];
        Assert.areEqual('Open', m.Status__c);
        Assert.areEqual(UserInfo.getUserId(), m.Responsible_Attorney__c);
        Intake__c after = [SELECT Status__c, Matter__c FROM Intake__c WHERE Id = :i.Id];
        Assert.areEqual('Approved', after.Status__c);
        Assert.areEqual(matterId, after.Matter__c);
        Assert.areEqual(matterId, [SELECT Matter__c FROM Conflict_Check__c WHERE Intake__c = :i.Id].Matter__c);
        // client account, client contact, attorney (auto) + opposing party
        Assert.areEqual(4, [SELECT COUNT() FROM Participant__c WHERE Matter__c = :matterId]);
    }

    @IsTest
    static void flowEntryPointConverts() {
        Intake__c i = newIntake('Approved', 'Waived');
        List<Id> ids = IntakeService.convertFromFlow(new List<Id>{ i.Id });
        Assert.isNotNull(ids[0]);
    }

    @IsTest
    static void rejectsUnapprovedIntake() {
        Intake__c i = newIntake('Submitted', 'Clear');
        try {
            IntakeService.convertIntake(i.Id);
            Assert.fail('Expected an error');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Only approved'));
        }
    }

    @IsTest
    static void rejectsUnclearedConflict() {
        Intake__c i = newIntake('Approved', 'Potential Conflict');
        try {
            IntakeService.convert(new List<Id>{ i.Id });
            Assert.fail('Expected an error');
        } catch (IntakeService.IntakeException e) {
            Assert.isTrue(e.getMessage().contains('conflict check'));
        }
    }

    @IsTest
    static void rejectsSecondConversion() {
        Intake__c i = newIntake('Approved', 'Clear');
        IntakeService.convert(new List<Id>{ i.Id });
        try {
            IntakeService.convert(new List<Id>{ i.Id });
            Assert.fail('Expected an error');
        } catch (IntakeService.IntakeException e) {
            Assert.isTrue(e.getMessage().contains('already been converted'));
        }
    }
}
