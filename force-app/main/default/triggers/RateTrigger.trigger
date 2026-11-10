trigger RateTrigger on Rate__c (before insert, before update) {
    if (!MatterManagementSettings.isDisabled('Disable_Rate_Trigger__c')) {
        RateTriggerHandler.enforceSingleDefault(Trigger.new);
    }
}
