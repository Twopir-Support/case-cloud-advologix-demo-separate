trigger UserTimekeeperTrigger on User (after insert, after update) {
    if (!MatterManagementSettings.isDisabled('Disable_Rate_Trigger__c')) {
        TimekeeperService.onUsersSaved(Trigger.new, Trigger.oldMap);
    }
}
