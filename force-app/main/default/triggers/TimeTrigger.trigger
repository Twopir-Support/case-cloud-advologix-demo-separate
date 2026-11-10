trigger TimeTrigger on Time__c (before insert, before update, before delete) {
    if (MatterManagementSettings.isDisabled('Disable_Time_Trigger__c')) {
        return;
    }
    if (Trigger.isDelete) {
        BillableTriggerHandler.beforeDelete(Trigger.old);
    } else {
        BillableTriggerHandler.timeBeforeSave(Trigger.new, Trigger.oldMap);
    }
}
