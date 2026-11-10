trigger ContentDocumentLegalHoldTrigger on ContentDocument (before delete) {
    if (!MatterManagementSettings.isDisabled('Disable_Legal_Hold_Trigger__c')) {
        LegalHoldService.guardFiles(Trigger.old);
    }
}
