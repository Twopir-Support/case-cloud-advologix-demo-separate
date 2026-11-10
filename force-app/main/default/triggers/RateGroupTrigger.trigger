trigger RateGroupTrigger on Rate_Group__c (before delete) {
    if (!MatterManagementSettings.isDisabled('Disable_Rate_Trigger__c')) {
        RateTriggerHandler.blockRateGroupDelete(Trigger.old);
    }
}
