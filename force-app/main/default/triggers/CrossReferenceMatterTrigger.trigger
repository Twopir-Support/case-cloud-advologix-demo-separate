trigger CrossReferenceMatterTrigger on Cross_Reference_Matter__c (before delete) {
    if (!MatterManagementSettings.isDisabled('Disable_Legal_Hold_Trigger__c')) {
        LegalHoldGuard.blockDeletes(Trigger.old, 'Matter__c');
    }
}
