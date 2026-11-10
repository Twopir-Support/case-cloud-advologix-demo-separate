@IsTest
private class ScreenControllersTest {
    @IsTest
    static void billingPreviewTimelineAndChecklist() {
        Account a = MatterTestDataFactory.account('Screen Co');
        Contact c = MatterTestDataFactory.contact('Ana', 'Screen', a.Id);
        Matter__c m = MatterTestDataFactory.matter('Screen Matter', a.Id, c.Id);
        update new Matter__c(Id = m.Id, Statute_of_Limitations__c = Date.today().addYears(1));
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('TK', 100);
        Time__c t = MatterTestDataFactory.timeEntry(m.Id, tk.Id, 2);
        Expense__c x = MatterTestDataFactory.expense(m.Id, 50);
        insert new Offer_and_Demand__c(Matter__c = m.Id, Type__c = 'Demand', Amount__c = 90000, Date__c = Date.today(), Party__c = 'Insurer');
        insert new Comment__c(Matter__c = m.Id, Comment__c = 'Spoke to court clerk');
        insert new Event(WhatId = m.Id, Subject = 'Mediation', StartDateTime = System.now(), EndDateTime = System.now().addHours(1));
        Task task = new Task(WhatId = m.Id, Subject = 'Draft motion', ActivityDate = Date.today());
        insert task;

        List<BillingPreviewController.AccountGroup> g = BillingPreviewController.getPreview(m.Id, null, null, null, null, true, true);
        Assert.areEqual(1, g.size());
        Assert.areEqual(250, g[0].total);
        Assert.areEqual(1, BillingPreviewController.getPreview(a.Id, Date.today().addDays(-5), Date.today(), new List<String>{ 'Bill' }, new List<String>{ 'Unprocessed' }, true, false).size());
        Assert.isFalse(BillingPreviewController.getPreview(null, null, null, null, null, null, null).isEmpty());
        Assert.areEqual(2, BillingPreviewController.updateDisposition(new List<Id>{ t.Id, x.Id }, 'Bill'));

        BillingService.createInvoice(m.Id, Date.today().addYears(1));
        update new Matter__c(Id = m.Id, Legal_Hold__c = true);
        List<MatterTimelineController.Item> items = MatterTimelineController.getTimeline(m.Id);
        Assert.isTrue(items.size() >= 9);

        Assert.areEqual(1, TaskChecklistController.getTasks(m.Id, false).size());
        TaskChecklistController.completeTask(task.Id);
        Assert.areEqual(0, TaskChecklistController.getTasks(m.Id, false).size());
        Assert.areEqual(1, TaskChecklistController.getTasks(m.Id, true).size());

        Map<String, Object> d = SettlementCalculatorController.getDefaults(m.Id);
        Assert.areEqual(90000, d.get('grossSettlement'));
        Assert.areEqual(50, d.get('caseCosts'));
    }

    @IsTest
    static void batchTimeFocusAndDates() {
        Account a = MatterTestDataFactory.account('Batch Co');
        Matter__c m = MatterTestDataFactory.matter('Batch Matter', a.Id, null);
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('Me', 150);
        Assert.areEqual(tk.Id, BatchTimeController.getContext().get('timekeeperId'));
        BatchTimeController.Row r = new BatchTimeController.Row();
        r.matterId = m.Id; r.timekeeperId = tk.Id; r.hours = 1.5; r.narrative = 'Research';
        Assert.areEqual(1, BatchTimeController.saveEntries(JSON.serialize(new List<BatchTimeController.Row>{ r })));
        r.hours = null;
        try {
            BatchTimeController.saveEntries(JSON.serialize(new List<BatchTimeController.Row>{ r }));
            Assert.fail('Expected validation');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }

        Assert.isTrue(FocusMatterService.toggle(m.Id));
        insert new Task(WhatId = m.Id, Subject = 'Overdue', ActivityDate = Date.today().addDays(-1));
        List<FocusMatterService.FocusRow> rows = FocusMatterService.getMyFocusMatters();
        Assert.areEqual(1, rows.size());
        Assert.isTrue(rows[0].overdue);
        Assert.isFalse(FocusMatterService.toggle(m.Id));

        Date monday = Date.newInstance(2026, 11, 2);
        Assert.areEqual(Date.newInstance(2026, 11, 9), DateCalculationService.addDays(monday, 5, true));
        Assert.areEqual(Date.newInstance(2026, 10, 26), DateCalculationService.addDays(monday, -5, true));
        Assert.areEqual(monday.addDays(10), DateCalculationService.addDays(monday, 10, false));
        Assert.isNull(DateCalculationService.addDays(null, 1, true));
        Map<String, Integer> between = DateCalculationService.daysBetween(monday, Date.newInstance(2026, 11, 9));
        Assert.areEqual(7, between.get('calendarDays'));
        Assert.areEqual(5, between.get('businessDays'));
        Assert.areEqual(0, DateCalculationService.daysBetween(null, null).get('calendarDays'));
        DateCalculationService.Request req = new DateCalculationService.Request();
        req.startDate = monday; req.days = 1; req.businessDaysOnly = true;
        Assert.areEqual(monday.addDays(1), DateCalculationService.calculateFromFlow(new List<DateCalculationService.Request>{ req })[0]);
    }

    @IsTest
    static void participantRecordTypesAndIntakeRecordType() {
        Account a = MatterTestDataFactory.account('RT Co');
        Matter__c m = MatterTestDataFactory.matter('RT Matter', a.Id, null);
        Participant__c other = new Participant__c(Matter__c = m.Id, Other_Name__c = 'Witness X', Role__c = 'Witness');
        insert other;
        Map<String, Schema.RecordTypeInfo> rts = Participant__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (rts.containsKey('Other') && rts.get('Other').isAvailable()) {
            Assert.areEqual(rts.get('Other').getRecordTypeId(), [SELECT RecordTypeId FROM Participant__c WHERE Id = :other.Id].RecordTypeId);
        }
        Intake__c i = new Intake__c(Name = 'RT Intake', Status__c = 'Approved', Conflict_Status__c = 'Clear', Matter_Record_Type__c = 'Litigation');
        insert i;
        Id matterId = IntakeService.convert(new List<Id>{ i.Id })[0];
        Map<String, Schema.RecordTypeInfo> mrts = Matter__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        Assert.areEqual(mrts.get('Litigation').getRecordTypeId(), [SELECT RecordTypeId FROM Matter__c WHERE Id = :matterId].RecordTypeId);
    }
}
