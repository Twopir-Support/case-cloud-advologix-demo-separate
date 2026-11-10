trigger ExpenseTrigger on Expense__c (before insert, before update, before delete) {
    if (MatterManagementSettings.isDisabled('Disable_Expense_Trigger__c')) {
        return;
    }
    if (Trigger.isDelete) {
        BillableTriggerHandler.beforeDelete(Trigger.old);
    } else {
        BillableTriggerHandler.expenseBeforeSave(Trigger.new, Trigger.oldMap);
    }
}
