@IsTest
private class BillingServiceTest {

    private static Matter__c setupMatter(String feeType, Decimal fixedAmt, Decimal cap, Decimal discount) {
        Account a = MatterTestDataFactory.account('Halvorsk Test Co');
        Matter__c m = MatterTestDataFactory.matter('Halvorsk Billing', a.Id, null);
        Matter_Fee_Arrangement__c mfa = new Matter_Fee_Arrangement__c(Matter__c = m.Id, Fee_Type__c = feeType,
            Fee_Arrangement_Price__c = fixedAmt, Cap_Amount__c = cap, Discount_Percentage__c = discount,
            Default_for_Fees__c = true, Default_for_Expenses__c = true);
        insert mfa;
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('Test Associate', 200);
        MatterTestDataFactory.timeEntry(m.Id, tk.Id, 2);   // 400
        MatterTestDataFactory.timeEntry(m.Id, tk.Id, 3);   // 600
        MatterTestDataFactory.expense(m.Id, 150);
        return m;
    }

    @IsTest
    static void hourlyWithDiscount() {
        Matter__c m = setupMatter('Hourly', null, null, 10);
        Test.startTest();
        Id invId = BillingService.generateInvoice(m.Id);
        Test.stopTest();
        Invoice__c inv = [SELECT Fees_Subtotal__c, Expenses_Subtotal__c, Discount_Amount__c, Total_Amount__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual(1000, inv.Fees_Subtotal__c);
        Assert.areEqual(150, inv.Expenses_Subtotal__c);
        Assert.areEqual(100, inv.Discount_Amount__c);
        Assert.areEqual(1050, inv.Total_Amount__c);
        Assert.areEqual(Date.today(), [SELECT LastBillDate__c FROM Matter_Fee_Arrangement__c WHERE Matter__c = :m.Id].LastBillDate__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Time__c WHERE Matter__c = :m.Id AND Status__c = 'Unprocessed']);
        Matter__c after = [SELECT Total_Invoiced__c, Unbilled_Time_Value__c FROM Matter__c WHERE Id = :m.Id];
        Assert.areEqual(1050, after.Total_Invoiced__c);
        Assert.areEqual(0, after.Unbilled_Time_Value__c == null ? 0 : after.Unbilled_Time_Value__c);
    }

    @IsTest
    static void fixedFeeBillsOnce() {
        Matter__c m = setupMatter('Fixed Fee', 5000, null, null);
        Id invId = BillingService.createInvoice(m.Id, Date.today());
        Invoice__c inv = [SELECT Fees_Subtotal__c, Total_Amount__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual(5000, inv.Fees_Subtotal__c);
        Assert.areEqual(5150, inv.Total_Amount__c);
        try {
            BillingService.createInvoice(m.Id, Date.today());
            Assert.fail('Expected nothing left to bill');
        } catch (BillingService.BillingException e) {
            Assert.isTrue(e.getMessage().contains('no unbilled'));
        }
    }

    @IsTest
    static void contingencyBillsExpensesOnly() {
        Matter__c m = setupMatter('Contingency', null, null, null);
        BillingService.Request req = new BillingService.Request();
        req.matterId = m.Id;
        Id invId = BillingService.generateFromFlow(new List<BillingService.Request>{ req })[0];
        Invoice__c inv = [SELECT Fees_Subtotal__c, Total_Amount__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual(0, inv.Fees_Subtotal__c == null ? 0 : inv.Fees_Subtotal__c);
        Assert.areEqual(150, inv.Total_Amount__c);
        Assert.areEqual(2, [SELECT COUNT() FROM Time__c WHERE Matter__c = :m.Id AND Status__c = 'Unprocessed']);
    }

    @IsTest
    static void cappedFeeWritesOffExcess() {
        Matter__c m = setupMatter('Capped Fee', null, 700, null);
        Id invId = BillingService.createInvoice(m.Id, Date.today());
        Invoice__c inv = [SELECT Discount_Amount__c, Total_Amount__c FROM Invoice__c WHERE Id = :invId];
        Assert.areEqual(300, inv.Discount_Amount__c);
        Assert.areEqual(850, inv.Total_Amount__c);
    }

    @IsTest
    static void voidReturnsWorkToUnbilled() {
        Matter__c m = setupMatter('Hourly', null, null, null);
        Id invId = BillingService.createInvoice(m.Id, Date.today());
        BillingService.voidInvoice(invId);
        Assert.areEqual('Void', [SELECT Status__c FROM Invoice__c WHERE Id = :invId].Status__c);
        Assert.areEqual(2, [SELECT COUNT() FROM Time__c WHERE Matter__c = :m.Id AND Status__c = 'Unprocessed']);
        Assert.areEqual(1, [SELECT COUNT() FROM Expense__c WHERE Matter__c = :m.Id AND Status__c = 'Unprocessed']);
        try {
            BillingService.voidInvoice(invId);
            Assert.fail('Expected already void');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('already void'));
        }
    }

    @IsTest
    static void paidInvoiceCannotBeVoided() {
        Matter__c m = setupMatter('Hourly', null, null, null);
        Id invId = BillingService.createInvoice(m.Id, Date.today());
        update new Invoice__c(Id = invId, Amount_Paid__c = 100, Status__c = 'Partially Paid');
        try {
            BillingService.voidInvoices(new Set<Id>{ invId });
            Assert.fail('Expected an error');
        } catch (BillingService.BillingException e) {
            Assert.isTrue(e.getMessage().contains('payments recorded'));
        }
    }

    @IsTest
    static void nothingToBill() {
        Account a = MatterTestDataFactory.account('Empty Test Co');
        Matter__c m = MatterTestDataFactory.matter('Empty', a.Id, null);
        try {
            BillingService.generateInvoice(m.Id);
            Assert.fail('Expected an error');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('no unbilled'));
        }
    }
}
