trigger UTBMSCodeTrigger on UTBMS_Code__c (before delete) {
    BudgetService.guardCodes(Trigger.old);
}
