trigger MatterTrigger on Matter__c (before insert, before update, before delete, after insert, after update) {
    if (MatterManagementSettings.isDisabled('Disable_Matter_Trigger__c')) {
        return;
    }
    if (Trigger.isBefore) {
        if (Trigger.isInsert) MatterTriggerHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) MatterTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        if (Trigger.isDelete) MatterTriggerHandler.beforeDelete(Trigger.old);
    } else {
        MatterTriggerHandler.afterSave(Trigger.new, Trigger.oldMap);
    }
}
