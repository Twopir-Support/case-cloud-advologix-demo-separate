@IsTest
private class TransactionAndRecurrenceTest {
    static Matter__c setup() {
        Account a = MatterTestDataFactory.account('Retainer Co');
        Matter__c m = MatterTestDataFactory.matter('Retainer Matter', a.Id, null);
        insert new Matter_Fee_Arrangement__c(Matter__c = m.Id, Fee_Type__c = 'Retainer', Fee_Arrangement_Price__c = 2500, Recurrence__c = 'Monthly',
            NextBillDate__c = Date.today().addMonths(-2), Default_for_Fees__c = true, Default_for_Expenses__c = true);
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('TK', 100);
        MatterTestDataFactory.timeEntry(m.Id, tk.Id, 2);
        MatterTestDataFactory.expense(m.Id, 40);
        Budget__c b = new Budget__c(Name = 'B', Matter__c = m.Id, Fee_Budget__c = 5000, Active__c = true);
        insert b;
        return m;
    }

    @IsTest
    static void recurringFeesAreGeneratedBilledAndVoided() {
        Matter__c m = setup();
        Assert.areEqual(3, RecurrenceService.generateDue(Date.today()));
        Assert.isTrue([SELECT NextBillDate__c FROM Matter_Fee_Arrangement__c WHERE Matter__c = :m.Id].NextBillDate__c > Date.today());
        Id inv = BillingService.createInvoice(m.Id, Date.today());
        Invoice__c i = [SELECT Fees_Subtotal__c, Total_Amount__c FROM Invoice__c WHERE Id = :inv];
        Assert.areEqual(7700, i.Fees_Subtotal__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Recurrence_Transaction__c WHERE Status__c = 'Unprocessed']);
        BillingService.voidInvoices(new Set<Id>{ inv });
        Assert.areEqual(3, [SELECT COUNT() FROM Recurrence_Transaction__c WHERE Status__c = 'Unprocessed']);
        Assert.areEqual(0, RecurrenceService.generateFromFlow(new List<Date>{ Date.today() })[0]);
        Test.startTest();
        new RecurrenceService().execute(null);
        Test.stopTest();
    }

    @IsTest
    static void transactionsRebuild() {
        Matter__c m = setup();
        RecurrenceService.generateDue(Date.today());
        BillingService.createInvoice(m.Id, Date.today());
        Integer n = TransactionService.refreshMatter(m.Id);
        // time, expense, 3 recurrences, budget, invoice lines (1 time + 1 expense + 3 recurring)
        Assert.areEqual(11, n);
        Assert.areEqual(1, [SELECT COUNT() FROM Transaction__c WHERE Transaction_Type__c = 'Estimate']);
        insert new Budget_Detail__c(Budget__c = [SELECT Id FROM Budget__c WHERE Matter__c = :m.Id].Id, Fee_Amount__c = 100);
        Test.startTest();
        new TransactionsBatch().execute(null);
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM Transaction__c WHERE Source__c = 'Budget Detail']);
    }

    @IsTest
    static void refreshAllStartsBatch() {
        setup();
        Test.startTest();
        Assert.areEqual(1, TransactionService.refreshAll(new List<String>()).size());
        Test.stopTest();
        Assert.isTrue([SELECT COUNT() FROM Transaction__c] > 0);
    }
}
