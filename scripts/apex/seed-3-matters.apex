// Matter Management sample data, step 3 of 4: approve and convert intakes into matters,
// add two direct matters, fee arrangements, budgets, extra participants and activity plans.
Id me = UserInfo.getUserId();
Date today = Date.today();
Map<String, Id> acc = new Map<String, Id>();
for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE '% (Sample)']) acc.put(a.Name.substringBefore(' ('), a.Id);
Map<String, Id> con = new Map<String, Id>();
for (Contact c : [SELECT Id, Name FROM Contact WHERE Name IN ('Dana Whitfield','Priya Raman','Elena Calloway','Marcus Delgado','Tom Reyes','Grace Okafor','Jordan Pike','Nina Albright') AND Email LIKE '%@example.com']) con.put(c.Name, c.Id);

// 1. Approve the six cleared intakes and convert them
List<Intake__c> ready = [SELECT Id, Name FROM Intake__c WHERE Status__c = 'Submitted' AND Conflict_Status__c = 'Clear' ORDER BY Name];
for (Intake__c i : ready) i.Status__c = 'Approved';
update ready;
List<Id> ids = new List<Id>();
for (Intake__c i : ready) ids.add(i.Id);
IntakeService.convert(ids);


// 2. The Ashford intake names our existing client as the adverse party: expect a potential conflict
Intake__c ashford = [SELECT Id FROM Intake__c WHERE Name = 'Ashford Logistics v. Harborline Freight'];
ConflictSearchService.checkIntake(ashford.Id);
update new Intake__c(Id = ashford.Id, Status__c = 'Submitted');

// 3. Enrich converted matters
Map<String, Rate_Group__c> groups = new Map<String, Rate_Group__c>();
for (Rate_Group__c g : [SELECT Id, Name FROM Rate_Group__c]) groups.put(g.Name, g);
Id standard = groups.get('Standard Rates 2026').Id;
Id panel = groups.get('Insurance Panel Rates 2026').Id;
Map<String, Matter__c> m = new Map<String, Matter__c>();
for (Matter__c x : [SELECT Id, Name, Type__c FROM Matter__c]) m.put(x.Type__c, x);

Matter__c pi = m.get('Personal Injury');
pi.Stage__c = 'Investigation'; pi.Open_Date__c = today.addDays(-35); pi.Statute_of_Limitations__c = today.addDays(-75).addYears(2);
pi.Rate_Group__c = standard; pi.Paralegal__c = me;
Matter__c fam = m.get('Family Law');
fam.Stage__c = 'Negotiation'; fam.Open_Date__c = today.addDays(-34); fam.Court__c = 'County Family Court'; fam.Case_Number__c = 'FAM-2026-00417'; fam.Rate_Group__c = standard;
Matter__c lit = m.get('Commercial Litigation');
lit.Stage__c = 'Discovery'; lit.Open_Date__c = today.addDays(-32); lit.Court__c = 'Superior Court, Commercial Division'; lit.Case_Number__c = '2026-CV-01482';
lit.Rate_Group__c = standard; lit.Paralegal__c = me;
Matter__c emp = m.get('Employment');
emp.Stage__c = 'Pleadings'; emp.Open_Date__c = today.addDays(-30); emp.Court__c = 'State Civil Rights Agency'; emp.Case_Number__c = 'CRA-26-3391'; emp.Rate_Group__c = standard;
Matter__c corp = m.get('Corporate & Transactions');
corp.Stage__c = 'Negotiation'; corp.Open_Date__c = today.addDays(-29); corp.Rate_Group__c = standard;
Matter__c re = m.get('Real Estate');
re.Stage__c = 'Pleadings'; re.Open_Date__c = today.addDays(-27); re.Court__c = 'County Circuit Court'; re.Case_Number__c = '2026-LN-0219'; re.Rate_Group__c = standard;
update new List<Matter__c>{ pi, fam, lit, emp, corp, re };

// 4. Two matters opened directly (no intake): a child appeal and an insurance panel defense
Matter__c appeal = new Matter__c(Name = 'Harborline Freight - Cargo Claim Appeal', Type__c = 'Commercial Litigation',
    Primary_Account__c = acc.get('Harborline Freight Co'), Primary_Contact__c = con.get('Dana Whitfield'), Responsible_Attorney__c = me,
    Parent_Matter__c = lit.Id, Status__c = 'Pending', Stage__c = 'Pleadings', Open_Date__c = today.addDays(-12), Rate_Group__c = standard,
    Court__c = 'Court of Appeals, Second District', Case_Number__c = 'A-26-0773', Description__c = 'Appeal of the summary judgment on the 2025 cargo loss claim.');
Matter__c defense = new Matter__c(Name = 'Summit Ridge - Ortiz v. Insured (Panel Defense)', Type__c = 'Commercial Litigation',
    Primary_Account__c = acc.get('Summit Ridge Insurance'), Primary_Contact__c = con.get('Grace Okafor'), Responsible_Attorney__c = me,
    Status__c = 'Open', Stage__c = 'Discovery', Open_Date__c = today.addDays(-25), Rate_Group__c = panel,
    Court__c = 'Superior Court, Civil Division', Case_Number__c = '2026-CV-02210', Description__c = 'Defense of an insured business in a premises liability claim under the insurer panel program.');
insert new List<Matter__c>{ appeal, defense };

// 5. Matter fee arrangements copied from the firm templates
Map<String, Fee_Arrangement__c> fa = new Map<String, Fee_Arrangement__c>();
for (Fee_Arrangement__c f : [SELECT Id, Name, Fee_Type__c, Fee_Arrangement_Price__c, Contingency_Percentage__c, Cap_Amount__c, Discount_Percentage__c FROM Fee_Arrangement__c]) fa.put(f.Name, f);
Matter_Fee_Arrangement__c mfa(Id matterId, Fee_Arrangement__c f, Date startDate) {
    return new Matter_Fee_Arrangement__c(Matter__c = matterId, Source_Fee_Arrangement__c = f.Id, Fee_Type__c = f.Fee_Type__c,
        Fee_Arrangement_Price__c = f.Fee_Arrangement_Price__c, Contingency_Percentage__c = f.Contingency_Percentage__c, Cap_Amount__c = f.Cap_Amount__c,
        Discount_Percentage__c = f.Discount_Percentage__c, Default_for_Fees__c = true, Default_for_Expenses__c = true, Start_Date__c = startDate);
}
insert new List<Matter_Fee_Arrangement__c>{
    mfa(pi.Id, fa.get('Personal Injury Contingency 33.3%'), pi.Open_Date__c),
    mfa(fam.Id, fa.get('Uncontested Divorce Flat Fee'), fam.Open_Date__c),
    mfa(lit.Id, fa.get('Standard Hourly'), lit.Open_Date__c),
    mfa(emp.Id, fa.get('Employment Defense Capped'), emp.Open_Date__c),
    mfa(corp.Id, fa.get('Corporate Retainer 10% Discount'), corp.Open_Date__c),
    mfa(re.Id, fa.get('Standard Hourly'), re.Open_Date__c),
    mfa(appeal.Id, fa.get('Standard Hourly'), appeal.Open_Date__c),
    mfa(defense.Id, fa.get('Standard Hourly'), defense.Open_Date__c)
};

// 6. Budgets
insert new List<Budget__c>{
    new Budget__c(Name = 'Phase 1 - through discovery', Matter__c = lit.Id, Fee_Budget__c = 60000, Expense_Budget__c = 15000, Budget_Start__c = lit.Open_Date__c, Budget_End__c = today.addMonths(6), Active__c = true),
    new Budget__c(Name = 'Agency response and mediation', Matter__c = emp.Id, Fee_Budget__c = 25000, Expense_Budget__c = 3000, Budget_Start__c = emp.Open_Date__c, Budget_End__c = today.addMonths(4), Active__c = true),
    new Budget__c(Name = 'Acquisition through closing', Matter__c = corp.Id, Fee_Budget__c = 40000, Expense_Budget__c = 2500, Budget_Start__c = corp.Open_Date__c, Budget_End__c = today.addMonths(3), Active__c = true),
    new Budget__c(Name = 'Lien enforcement', Matter__c = re.Id, Fee_Budget__c = 18000, Expense_Budget__c = 2000, Active__c = true),
    new Budget__c(Name = 'Panel budget - initial', Matter__c = defense.Id, Fee_Budget__c = 30000, Expense_Budget__c = 6000, Active__c = true, Notes__c = 'Approved by carrier on intake.'),
    new Budget__c(Name = 'Appeal briefing', Matter__c = appeal.Id, Fee_Budget__c = 22000, Expense_Budget__c = 1500, Active__c = true)
};

// 7. Additional participants
insert new List<Participant__c>{
    new Participant__c(Matter__c = pi.Id, Contact__c = con.get('Grace Okafor'), Role__c = 'Insurance Adjuster', Notes__c = 'Adjuster for the at-fault carrier.'),
    new Participant__c(Matter__c = pi.Id, Other_Name__c = 'Dr. Hannah Sloan', Role__c = 'Medical Provider', Notes__c = 'Treating orthopedist.'),
    new Participant__c(Matter__c = pi.Id, Other_Name__c = 'Pratt & Vance LLP', Role__c = 'Opposing Counsel'),
    new Participant__c(Matter__c = lit.Id, Contact__c = con.get('Nina Albright'), Role__c = 'Witness', Notes__c = 'Records custodian; key witness on inventory counts.'),
    new Participant__c(Matter__c = lit.Id, Other_Name__c = 'Hon. Miriam Ostrow', Role__c = 'Judge'),
    new Participant__c(Matter__c = lit.Id, Other_Name__c = 'Dr. Felix Amari, CPA', Role__c = 'Expert Witness', Notes__c = 'Damages expert.'),
    new Participant__c(Matter__c = defense.Id, Other_Name__c = 'Carla Ortiz', Role__c = 'Opposing Party'),
    new Participant__c(Matter__c = defense.Id, Other_Name__c = 'Bell Torres Injury Law', Role__c = 'Opposing Counsel'),
    new Participant__c(Matter__c = appeal.Id, Other_Name__c = 'Coastal Warehousing Partners', Role__c = 'Opposing Party')
};

// 8. Activity plans for matters whose practice area has a template
Integer tasks = 0;
for (Matter__c x : new List<Matter__c>{ pi, fam, lit, emp, appeal, defense }) {
    tasks += ActionPlansUtilitiesExternal.apply(null, null, x.Id);
}
System.debug('Step 3 done: 8 matters, 8 fee arrangements, 6 budgets, ' + tasks + ' tasks. SOQL used: ' + Limits.getQueries());
