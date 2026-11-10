trigger BudgetDetailTrigger on Budget_Detail__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    if (MatterManagementSettings.isDisabled('Disable_Budget_Trigger__c')) {
        return;
    }
    if (Trigger.isBefore) {
        BudgetService.detailBefore(Trigger.isDelete ? Trigger.old : Trigger.new, Trigger.isDelete);
    } else {
        BudgetService.detailAfter(Trigger.isDelete ? Trigger.old : Trigger.new);
    }
}
