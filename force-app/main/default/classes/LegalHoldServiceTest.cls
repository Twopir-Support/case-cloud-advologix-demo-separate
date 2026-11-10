@IsTest
public class LegalHoldServiceTest {
    public static String lastPayload;
    public class RecordingCallback implements LegalHoldCallback {
        public void handle(String payload) { lastPayload = payload; }
    }

    @IsTest
    static void holdLifecycleWithNoticesCallbackAndChildGuards() {
        MatterManagementSettings.testOverride = new Matter_Management_Settings__c(Send_Legal_Hold_Emails__c = true,
            Legal_Hold_Callback_Class__c = 'LegalHoldServiceTest.RecordingCallback');
        Account a = MatterTestDataFactory.account('Hold Co');
        Contact c = MatterTestDataFactory.contact('Ivo', 'Hold', a.Id);
        Matter__c m = MatterTestDataFactory.matter('Hold Matter', a.Id, c.Id);
        Cross_Reference_Matter__c x = new Cross_Reference_Matter__c(Matter__c = m.Id, Related_Matter__c = MatterTestDataFactory.matter('Other', a.Id, null).Id);
        Offer_and_Demand__c od = new Offer_and_Demand__c(Matter__c = m.Id, Type__c = 'Demand', Amount__c = 1000);
        Comment__c cm = new Comment__c(Matter__c = m.Id, Comment__c = 'Note');
        insert new List<SObject>{ x, od, cm };
        ContentVersion cv = new ContentVersion(Title = 'Evidence', PathOnClient = 'e.txt', VersionData = Blob.valueOf('x'), FirstPublishLocationId = m.Id);
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Test.startTest();
        update new Matter__c(Id = m.Id, Legal_Hold__c = true);
        Test.stopTest();

        Assert.isTrue(lastPayload.contains('Added'));
        Assert.isFalse(Database.delete(x, false).isSuccess());
        Assert.isFalse(Database.delete(od, false).isSuccess());
        Assert.isFalse(Database.delete(cm, false).isSuccess());
        Assert.isFalse(Database.delete(new ContentDocument(Id = docId), false).isSuccess());
        Assert.areEqual(1, LegalHoldService.sendNotices([SELECT Id, Matter__c, Status__c, Custodian_Contact__c, Custodian_User__c
            FROM Matter_Legal_Hold_Acknowledgement__c WHERE Custodian_Contact__c = :c.Id]));

        Matter_Legal_Hold_Acknowledgement__c ack = [SELECT Id FROM Matter_Legal_Hold_Acknowledgement__c WHERE Matter__c = :m.Id LIMIT 1];
        LegalHoldService.acknowledge(ack.Id);
        Assert.areEqual('Acknowledged', [SELECT Status__c FROM Matter_Legal_Hold_Acknowledgement__c WHERE Id = :ack.Id].Status__c);

        update new Matter__c(Id = m.Id, Legal_Hold__c = false);
        Assert.isTrue(lastPayload.contains('Removed'));
        try {
            LegalHoldService.acknowledge(ack.Id);
            Assert.fail('Expected released error');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('released'));
        }
        Assert.isTrue(Database.delete(new ContentDocument(Id = docId), false).isSuccess());
    }

    @IsTest
    static void switchesAndMissingCallback() {
        MatterManagementSettings.testOverride = new Matter_Management_Settings__c(Send_Legal_Hold_Emails__c = false,
            Legal_Hold_Callback_Class__c = 'NoSuchClass', Disable_Legal_Hold_Trigger__c = true);
        Assert.isTrue(MatterManagementSettings.isDisabled('Disable_Legal_Hold_Trigger__c'));
        Account a = MatterTestDataFactory.account('Hold Co 2');
        Matter__c m = MatterTestDataFactory.matter('Hold 2', a.Id, null);
        update new Matter__c(Id = m.Id, Legal_Hold__c = true);
        Assert.areEqual(0, LegalHoldService.sendNotices([SELECT Id, Matter__c, Status__c, Custodian_Contact__c, Custodian_User__c FROM Matter_Legal_Hold_Acknowledgement__c]));
        MatterManagementSettings.testOverride = null;
        Assert.isNotNull(MatterManagementSettings.get());
    }
}
