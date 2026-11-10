trigger TimekeeperTrigger on Timekeeper__c (before delete) {
    if (!MatterManagementSettings.isDisabled('Disable_Rate_Trigger__c')) {
        RateTriggerHandler.blockTimekeeperDelete(Trigger.old);
    }
}
