@IsTest
private class BudgetServiceTest {
    @IsTest
    static void detailsRollUpAndLocking() {
        UTBMS_Code_Set__c set1 = new UTBMS_Code_Set__c(Name = 'Litigation', Default__c = true, Standard__c = true);
        UTBMS_Code_Set__c set2 = new UTBMS_Code_Set__c(Name = 'Other');
        insert new List<UTBMS_Code_Set__c>{ set1, set2 };
        Assert.isFalse(Database.insert(new UTBMS_Code_Set__c(Name = 'Second default', Default__c = true), false).isSuccess());
        Assert.isFalse(Database.delete(set1, false).isSuccess());
        UTBMS_Code__c l110 = new UTBMS_Code__c(Name = 'L110', UTBMS_Code_Set__c = set1.Id, Standard__c = true);
        UTBMS_Code__c x1 = new UTBMS_Code__c(Name = 'X1', UTBMS_Code_Set__c = set2.Id);
        insert new List<UTBMS_Code__c>{ l110, x1 };
        Assert.isFalse(Database.delete(l110, false).isSuccess());

        Account a = MatterTestDataFactory.account('Budget Co');
        Matter__c m = MatterTestDataFactory.matter('Budget Matter', a.Id, null);
        update new Matter__c(Id = m.Id, UTBMS_Code_Set__c = set1.Id);
        Budget__c b = new Budget__c(Name = 'Phase 1', Matter__c = m.Id, Active__c = true);
        insert b;
        insert new List<Budget_Detail__c>{
            new Budget_Detail__c(Budget__c = b.Id, UTBMS_Code__c = l110.Id, Fee_Amount__c = 1000, Expense_Amount__c = 100),
            new Budget_Detail__c(Budget__c = b.Id, Fee_Amount__c = 500) };
        Assert.isFalse(Database.insert(new Budget_Detail__c(Budget__c = b.Id, UTBMS_Code__c = x1.Id, Fee_Amount__c = 1), false).isSuccess());
        Budget__c after = [SELECT Fee_Budget__c, Expense_Budget__c, Remaining_Budget__c, Number_of_Budget_Details__c FROM Budget__c WHERE Id = :b.Id];
        Assert.areEqual(1500, after.Fee_Budget__c);
        Assert.areEqual(100, after.Expense_Budget__c);
        Assert.areEqual(2, after.Number_of_Budget_Details__c);
        Assert.areEqual(1600, [SELECT Budget_Total__c FROM Matter__c WHERE Id = :m.Id].Budget_Total__c);

        update new Budget__c(Id = b.Id, Locked__c = true);
        Assert.isFalse(Database.insert(new Budget_Detail__c(Budget__c = b.Id, Fee_Amount__c = 1), false).isSuccess());
        Assert.isFalse(Database.update(new Budget__c(Id = b.Id, Fee_Budget__c = 1), false).isSuccess());
        Assert.isFalse(Database.delete(b, false).isSuccess());
        try {
            BudgetService.applyTemplate(b.Id);
            Assert.fail('Expected locked');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('locked'));
        }
        update new Budget__c(Id = b.Id, Locked__c = false);
        delete [SELECT Id FROM Budget_Detail__c WHERE Budget__c = :b.Id AND UTBMS_Code__c = null];
        Assert.areEqual(1000, [SELECT Fee_Budget__c FROM Budget__c WHERE Id = :b.Id].Fee_Budget__c);
    }

    @IsTest
    static void applyTemplateByMatterType() {
        Budget_Template__c t = new Budget_Template__c(Name = 'Lit', Type__c = 'Commercial Litigation', Active__c = true);
        insert t;
        insert new List<Budget_Template_Detail__c>{
            new Budget_Template_Detail__c(Budget_Template__c = t.Id, Description__c = 'Pleadings', Fee_Amount__c = 5000),
            new Budget_Template_Detail__c(Budget_Template__c = t.Id, Description__c = 'Discovery', Fee_Amount__c = 9000, Expense_Amount__c = 2000) };
        Account a = MatterTestDataFactory.account('Tpl Co');
        Matter__c m = MatterTestDataFactory.matter('Tpl Matter', a.Id, null);
        Budget__c b = new Budget__c(Name = 'From template', Matter__c = m.Id, Active__c = true);
        insert b;
        Assert.areEqual(2, BudgetService.applyTemplate(b.Id));
        Assert.areEqual(14000, [SELECT Fee_Budget__c FROM Budget__c WHERE Id = :b.Id].Fee_Budget__c);
        Matter__c other = new Matter__c(Name = 'No template', Type__c = 'Immigration');
        insert other;
        Budget__c b2 = new Budget__c(Name = 'x', Matter__c = other.Id);
        insert b2;
        try {
            BudgetService.applyTemplate(b2.Id);
            Assert.fail('Expected no template');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('no active budget template'));
        }
    }
}
