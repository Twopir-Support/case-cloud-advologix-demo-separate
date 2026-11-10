@IsTest
private class MatterTriggerTest {

    @IsTest
    static void matterDefaultsAndParticipants() {
        Account a = MatterTestDataFactory.account('Trigger Test Co');
        Contact c = MatterTestDataFactory.contact('Pell', 'Trigger', a.Id);
        Matter__c m = new Matter__c(Name = 'Trigger Matter', Primary_Account__c = a.Id, Primary_Contact__c = c.Id,
            Responsible_Attorney__c = UserInfo.getUserId(), Paralegal__c = UserInfo.getUserId());
        insert m;
        m = [SELECT Status__c, Open_Date__c FROM Matter__c WHERE Id = :m.Id];
        Assert.areEqual('Open', m.Status__c);
        Assert.areEqual(Date.today(), m.Open_Date__c);
        Assert.areEqual(4, [SELECT COUNT() FROM Participant__c WHERE Matter__c = :m.Id AND Auto_Added__c = true]);

        // re-saving with the same values adds nothing; changing the contact adds one
        Contact c2 = MatterTestDataFactory.contact('Nara', 'Trigger', a.Id);
        update new Matter__c(Id = m.Id, Primary_Contact__c = c2.Id);
        Assert.areEqual(5, [SELECT COUNT() FROM Participant__c WHERE Matter__c = :m.Id]);

        update new Matter__c(Id = m.Id, Status__c = 'Closed');
        Assert.areEqual(Date.today(), [SELECT Close_Date__c FROM Matter__c WHERE Id = :m.Id].Close_Date__c);

        Matter__c closedAtInsert = new Matter__c(Name = 'Closed at insert', Status__c = 'Closed');
        insert closedAtInsert;
        Assert.isNotNull([SELECT Close_Date__c FROM Matter__c WHERE Id = :closedAtInsert.Id].Close_Date__c);
    }

    @IsTest
    static void legalHoldLifecycle() {
        Account a = MatterTestDataFactory.account('Hold Test Co');
        Contact c = MatterTestDataFactory.contact('Odo', 'Hold', a.Id);
        Matter__c m = MatterTestDataFactory.matter('Hold Matter', a.Id, c.Id);
        Expense__c e = MatterTestDataFactory.expense(m.Id, 50);

        update new Matter__c(Id = m.Id, Legal_Hold__c = true);
        // contact + attorney get acknowledgements; the client account does not
        Assert.areEqual(2, [SELECT COUNT() FROM Matter_Legal_Hold_Acknowledgement__c WHERE Matter__c = :m.Id AND Status__c = 'Pending']);

        Database.DeleteResult dr = Database.delete(e, false);
        Assert.isFalse(dr.isSuccess());
        Participant__c p = [SELECT Id FROM Participant__c WHERE Matter__c = :m.Id LIMIT 1];
        Assert.isFalse(Database.delete(p, false).isSuccess());
        Assert.isFalse(Database.delete(new Matter__c(Id = m.Id), false).isSuccess());
        Assert.isFalse(Database.update(new Matter__c(Id = m.Id, Status__c = 'Closed'), false).isSuccess());

        update new Matter__c(Id = m.Id, Legal_Hold__c = false);
        Assert.areEqual(2, [SELECT COUNT() FROM Matter_Legal_Hold_Acknowledgement__c WHERE Matter__c = :m.Id AND Status__c = 'Released']);
        Assert.isTrue(Database.delete(e, false).isSuccess());
    }

    @IsTest
    static void rateResolutionOrder() {
        Account a = MatterTestDataFactory.account('Rate Test Co');
        Rate_Group__c g = new Rate_Group__c(Name = 'Panel');
        insert g;
        Matter__c m = new Matter__c(Name = 'Rates', Primary_Account__c = a.Id, Rate_Group__c = g.Id);
        insert m;
        Matter__c m2 = new Matter__c(Name = 'Rates 2', Primary_Account__c = a.Id, Rate_Group__c = g.Id);
        insert m2;
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('Rate Partner', 500);
        Timekeeper__c tk2 = MatterTestDataFactory.timekeeper('Rate Paralegal', 120);
        insert new List<Rate__c>{
            new Rate__c(Timekeeper__c = tk.Id, Rate_Group__c = g.Id, Hourly_Rate__c = 400, Effective_Date__c = Date.today().addYears(-1)),
            new Rate__c(Timekeeper__c = tk.Id, Matter__c = m.Id, Hourly_Rate__c = 350, Effective_Date__c = Date.today().addYears(-1)),
            new Rate__c(Timekeeper__c = tk.Id, Matter__c = m2.Id, Hourly_Rate__c = 999, Effective_Date__c = Date.today().addYears(1))
        };
        Matter_Fee_Arrangement__c mfa = MatterTestDataFactory.feeArrangement(m.Id, 'Hourly');

        Time__c matterRate = MatterTestDataFactory.timeEntry(m.Id, tk.Id, 1);
        Time__c groupRate = MatterTestDataFactory.timeEntry(m2.Id, tk.Id, 1);
        Time__c defaultRate = MatterTestDataFactory.timeEntry(m2.Id, tk2.Id, 1);
        Assert.areEqual(350, [SELECT Rate__c FROM Time__c WHERE Id = :matterRate.Id].Rate__c);
        Assert.areEqual(400, [SELECT Rate__c FROM Time__c WHERE Id = :groupRate.Id].Rate__c);
        Assert.areEqual(120, [SELECT Rate__c FROM Time__c WHERE Id = :defaultRate.Id].Rate__c);
        Assert.areEqual(mfa.Id, [SELECT Matter_Fee_Arrangement__c FROM Time__c WHERE Id = :matterRate.Id].Matter_Fee_Arrangement__c);
        Time__c named = [SELECT Name FROM Time__c WHERE Id = :matterRate.Id];
        Assert.isTrue(named.Name.endsWith(' : Rates'), named.Name);

        Expense__c e = MatterTestDataFactory.expense(m.Id, 20);
        Assert.areEqual(mfa.Id, [SELECT Matter_Fee_Arrangement__c FROM Expense__c WHERE Id = :e.Id].Matter_Fee_Arrangement__c);
    }

    @IsTest
    static void billedRecordsAreLocked() {
        Account a = MatterTestDataFactory.account('Lock Test Co');
        Matter__c m = MatterTestDataFactory.matter('Lock', a.Id, null);
        Timekeeper__c tk = MatterTestDataFactory.timekeeper('Lock TK', 100);
        Time__c t = MatterTestDataFactory.timeEntry(m.Id, tk.Id, 1);
        Expense__c e = MatterTestDataFactory.expense(m.Id, 10);
        BillingService.createInvoice(m.Id, Date.today());

        Assert.isFalse(Database.update(new Time__c(Id = t.Id, Time_in_Hours__c = 5), false).isSuccess());
        Assert.isFalse(Database.update(new Expense__c(Id = e.Id, Amount__c = 99), false).isSuccess());
        Assert.isFalse(Database.delete(t, false).isSuccess());
        // narrative can still be corrected
        Assert.isTrue(Database.update(new Time__c(Id = t.Id, Narrative__c = 'Corrected'), false).isSuccess());

        Time__c dnb = new Time__c(Matter__c = m.Id, Timekeeper__c = tk.Id, Time_in_Hours__c = 1, Disposition__c = 'Do Not Bill');
        insert dnb;
        Assert.isFalse([SELECT Billable__c FROM Time__c WHERE Id = :dnb.Id].Billable__c);
        Expense__c dnbE = new Expense__c(Matter__c = m.Id, Amount__c = 5, Disposition__c = 'Do Not Bill');
        insert dnbE;
        Assert.isFalse([SELECT Billable__c FROM Expense__c WHERE Id = :dnbE.Id].Billable__c);
    }
}
