trigger CommentTrigger on Comment__c (before delete) {
    if (!MatterManagementSettings.isDisabled('Disable_Legal_Hold_Trigger__c')) {
        LegalHoldGuard.blockDeletes(Trigger.old, 'Matter__c');
    }
}
