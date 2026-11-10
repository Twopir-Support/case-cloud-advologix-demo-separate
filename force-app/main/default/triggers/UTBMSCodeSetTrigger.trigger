trigger UTBMSCodeSetTrigger on UTBMS_Code_Set__c (before insert, before update, before delete) {
    BudgetService.guardCodeSets(Trigger.isDelete ? Trigger.old : Trigger.new, Trigger.isDelete);
}
