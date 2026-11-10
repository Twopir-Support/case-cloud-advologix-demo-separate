trigger LegalHoldAckTrigger on Matter_Legal_Hold_Acknowledgement__c (after insert) {
    if (MatterManagementSettings.isDisabled('Disable_Legal_Hold_Trigger__c')) {
        return;
    }
    LegalHoldService.sendNotices(Trigger.new);
}
