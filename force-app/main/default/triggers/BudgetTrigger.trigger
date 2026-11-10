trigger BudgetTrigger on Budget__c (before update, before delete) {
    if (MatterManagementSettings.isDisabled('Disable_Budget_Trigger__c')) {
        return;
    }
    if (Trigger.isDelete) {
        BudgetService.budgetBeforeDelete(Trigger.old);
    } else {
        BudgetService.budgetBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
