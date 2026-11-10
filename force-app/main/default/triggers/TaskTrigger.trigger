trigger TaskTrigger on Task (after insert, after update) {
    if (!MatterManagementSettings.isDisabled('Disable_Activity_Trigger__c')) {
        ActivityTimeService.afterSave(Trigger.new, Trigger.oldMap);
    }
}
