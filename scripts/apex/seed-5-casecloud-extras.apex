// Matter Management sample data, step 5: code sets, budget templates and details, cross references, offers and demands,
// comments, skills, focus matters, recurring retainer fees, record types, logged time, an approval submission, transactions.
Id me = UserInfo.getUserId();
Date today = Date.today();
Map<String, Matter__c> m = new Map<String, Matter__c>();
for (Matter__c x : [SELECT Id, Name, Type__c, Parent_Matter__c, Rate_Group__r.Name FROM Matter__c]) {
    String key = x.Type__c;
    if (x.Parent_Matter__c != null) key = 'Appeal';
    else if (x.Rate_Group__r?.Name == 'Insurance Panel Rates 2026') key = 'Panel';
    m.put(key, x);
}
Matter__c lit = m.get('Commercial Litigation'), appeal = m.get('Appeal'), panel = m.get('Panel'), pi = m.get('Personal Injury'),
          fam = m.get('Family Law'), emp = m.get('Employment'), corp = m.get('Corporate & Transactions'), re = m.get('Real Estate');

// 1. UTBMS code set (standard, default) and link codes and litigation matters
UTBMS_Code_Set__c ledes = new UTBMS_Code_Set__c(Name = 'LEDES UTBMS Litigation Code Set', Default__c = true, Standard__c = true,
    Description__c = 'ABA litigation task (L), activity (A) and expense (E) codes used for LEDES billing.');
insert ledes;
List<UTBMS_Code__c> codes = [SELECT Id, Name FROM UTBMS_Code__c];
Map<String, Id> code = new Map<String, Id>();
for (UTBMS_Code__c c : codes) { c.UTBMS_Code_Set__c = ledes.Id; c.Standard__c = true; code.put(c.Name, c.Id); }
update codes;
for (Matter__c x : new List<Matter__c>{ lit, appeal, panel, emp }) x.UTBMS_Code_Set__c = ledes.Id;

// 2. Matter record types
Map<String, Schema.RecordTypeInfo> mrt = Matter__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
lit.RecordTypeId = mrt.get('Litigation').getRecordTypeId();
appeal.RecordTypeId = mrt.get('Litigation').getRecordTypeId();
panel.RecordTypeId = mrt.get('Litigation').getRecordTypeId();
emp.RecordTypeId = mrt.get('Litigation').getRecordTypeId();
pi.RecordTypeId = mrt.get('Personal_Injury').getRecordTypeId();
fam.RecordTypeId = mrt.get('Family_Law').getRecordTypeId();
corp.RecordTypeId = mrt.get('Transactional').getRecordTypeId();
re.RecordTypeId = mrt.get('General').getRecordTypeId();
update new List<Matter__c>{ lit, appeal, panel, emp, pi, fam, corp, re };
Map<String, String> intakeRt = new Map<String, String>{ 'Personal Injury' => 'Personal_Injury', 'Family Law' => 'Family_Law',
    'Commercial Litigation' => 'Litigation', 'Employment' => 'Litigation', 'Corporate & Transactions' => 'Transactional',
    'Real Estate' => 'General', 'Immigration' => 'General' };
List<Intake__c> intakes = [SELECT Id, Type__c FROM Intake__c];
for (Intake__c i : intakes) i.Matter_Record_Type__c = intakeRt.get(i.Type__c);
update intakes;
update [SELECT Id FROM Participant__c];   // trigger assigns Participant record types

// 3. Budget templates; apply one to the Harborline budget; detail lines on the employment budget
Budget_Template__c litTpl = new Budget_Template__c(Name = 'Commercial Litigation - Through Discovery', Type__c = 'Commercial Litigation', Active__c = true,
    UTBMS_Code_Set__c = ledes.Id, Description__c = 'Standard phase budget for a commercial dispute through the close of discovery.');
Budget_Template__c empTpl = new Budget_Template__c(Name = 'Employment Defense - Agency Stage', Type__c = 'Employment', Active__c = true,
    UTBMS_Code_Set__c = ledes.Id, Description__c = 'Agency charge response and mediation.');
insert new List<Budget_Template__c>{ litTpl, empTpl };
insert new List<Budget_Template_Detail__c>{
    new Budget_Template_Detail__c(Budget_Template__c = litTpl.Id, UTBMS_Code__c = code.get('L110'), Description__c = 'Fact investigation', Hours__c = 30, Fee_Amount__c = 10500),
    new Budget_Template_Detail__c(Budget_Template__c = litTpl.Id, UTBMS_Code__c = code.get('L120'), Description__c = 'Analysis and strategy', Hours__c = 20, Fee_Amount__c = 8000),
    new Budget_Template_Detail__c(Budget_Template__c = litTpl.Id, UTBMS_Code__c = code.get('L210'), Description__c = 'Pleadings', Hours__c = 25, Fee_Amount__c = 8500, Expense_Amount__c = 1000),
    new Budget_Template_Detail__c(Budget_Template__c = litTpl.Id, UTBMS_Code__c = code.get('L310'), Description__c = 'Written discovery', Hours__c = 45, Fee_Amount__c = 15000, Expense_Amount__c = 2000),
    new Budget_Template_Detail__c(Budget_Template__c = litTpl.Id, UTBMS_Code__c = code.get('L330'), Description__c = 'Depositions', Hours__c = 50, Fee_Amount__c = 18000, Expense_Amount__c = 12000),
    new Budget_Template_Detail__c(Budget_Template__c = empTpl.Id, UTBMS_Code__c = code.get('L110'), Description__c = 'Investigation and file review', Hours__c = 12, Fee_Amount__c = 4500),
    new Budget_Template_Detail__c(Budget_Template__c = empTpl.Id, UTBMS_Code__c = code.get('L250'), Description__c = 'Position statement', Hours__c = 30, Fee_Amount__c = 11000, Expense_Amount__c = 500),
    new Budget_Template_Detail__c(Budget_Template__c = empTpl.Id, UTBMS_Code__c = code.get('L120'), Description__c = 'Mediation preparation and attendance', Hours__c = 25, Fee_Amount__c = 9500, Expense_Amount__c = 2500)
};
Integer litDetails = BudgetService.applyTemplate([SELECT Id FROM Budget__c WHERE Matter__c = :lit.Id LIMIT 1].Id);
Integer empDetails = BudgetService.applyTemplate([SELECT Id FROM Budget__c WHERE Matter__c = :emp.Id LIMIT 1].Id);
update new Budget__c(Id = [SELECT Id FROM Budget__c WHERE Matter__c = :corp.Id LIMIT 1].Id, Locked__c = true, Notes__c = 'Locked after client approval.');

// 4. Cross references, offers and demands, comments
insert new List<Cross_Reference_Matter__c>{
    new Cross_Reference_Matter__c(Matter__c = lit.Id, Related_Matter__c = appeal.Id, Relationship__c = 'Appeal', Notes__c = 'Appeal of the 2025 cargo claim ruling.'),
    new Cross_Reference_Matter__c(Matter__c = appeal.Id, Related_Matter__c = lit.Id, Relationship__c = 'Prior Matter'),
    new Cross_Reference_Matter__c(Matter__c = pi.Id, Related_Matter__c = panel.Id, Relationship__c = 'Coverage', Notes__c = 'Same carrier (Summit Ridge) on both matters; check positional conflict before negotiating.'),
    new Cross_Reference_Matter__c(Matter__c = panel.Id, Related_Matter__c = pi.Id, Relationship__c = 'Related')
};
insert new List<Offer_and_Demand__c>{
    new Offer_and_Demand__c(Matter__c = pi.Id, Type__c = 'Demand', Amount__c = 250000, Date__c = today.addDays(-20), Party__c = 'Rowan Haulage Ltd insurer', Status__c = 'Rejected'),
    new Offer_and_Demand__c(Matter__c = pi.Id, Type__c = 'Offer', Amount__c = 85000, Date__c = today.addDays(-12), Party__c = 'Rowan Haulage Ltd insurer', Status__c = 'Rejected'),
    new Offer_and_Demand__c(Matter__c = pi.Id, Type__c = 'Counter-Demand', Amount__c = 180000, Date__c = today.addDays(-6), Party__c = 'Rowan Haulage Ltd insurer', Status__c = 'Rejected'),
    new Offer_and_Demand__c(Matter__c = pi.Id, Type__c = 'Counter-Offer', Amount__c = 140000, Date__c = today.addDays(-2), Expiration_Date__c = today.addDays(12), Party__c = 'Rowan Haulage Ltd insurer', Status__c = 'Open'),
    new Offer_and_Demand__c(Matter__c = panel.Id, Type__c = 'Demand', Amount__c = 150000, Date__c = today.addDays(-9), Party__c = 'Bell Torres Injury Law', Status__c = 'Open'),
    new Offer_and_Demand__c(Matter__c = lit.Id, Type__c = 'Offer', Amount__c = 400000, Date__c = today.addDays(-3), Party__c = 'Coastal Warehousing Partners', Status__c = 'Open', Notes__c = 'Without prejudice; expires after mediation.')
};
insert new List<Comment__c>{
    new Comment__c(Matter__c = lit.Id, Comment_Type__c = 'Court Update', Comment__c = 'Scheduling order entered: fact discovery closes in 120 days.'),
    new Comment__c(Matter__c = lit.Id, Comment_Type__c = 'Client Update', Comment__c = 'Client GC approved the mediation budget.'),
    new Comment__c(Matter__c = pi.Id, Comment_Type__c = 'Internal', Comment__c = 'Physio records still outstanding from the clinic; follow up Friday.'),
    new Comment__c(Matter__c = panel.Id, Comment_Type__c = 'Internal', Comment__c = 'Carrier wants a liability assessment before the next report.'),
    new Comment__c(Matter__c = fam.Id, Comment_Type__c = 'Client Update', Comment__c = 'Both parties signed the settlement agreement.'),
    new Comment__c(Matter__c = corp.Id, Comment_Type__c = 'General', Comment__c = 'Seller counsel returned the purchase agreement with redlines.')
};

// 5. Skills and certifications
Map<String, Id> tk = new Map<String, Id>();
for (Timekeeper__c t : [SELECT Id, Name FROM Timekeeper__c]) tk.put(t.Name, t.Id);
insert new List<Skill_Certification__c>{
    new Skill_Certification__c(Name = 'State Bar Admission', Type__c = 'Bar Admission', Issuing_Body__c = 'State Bar', Year_Text__c = '2009', Timekeeper__c = tk.get('Avery Collins')),
    new Skill_Certification__c(Name = 'Civil Trial Advocacy Certification', Type__c = 'Certification', Issuing_Body__c = 'National Board of Trial Advocacy', Year_Text__c = '2017', Timekeeper__c = tk.get('Avery Collins'), Expiration_Date__c = today.addYears(1)),
    new Skill_Certification__c(Name = 'State Bar Admission', Type__c = 'Bar Admission', Issuing_Body__c = 'State Bar', Year_Text__c = '2014', Timekeeper__c = tk.get('Morgan Lee')),
    new Skill_Certification__c(Name = 'Spanish (professional)', Type__c = 'Language', Year_Text__c = '2019', Timekeeper__c = tk.get('Sam Patel')),
    new Skill_Certification__c(Name = 'Juris Doctor', Type__c = 'Education', Issuing_Body__c = 'Law School', Year_Text__c = '2021', Timekeeper__c = tk.get('Riley Chen')),
    new Skill_Certification__c(Name = 'eDiscovery Specialist', Type__c = 'Certification', Issuing_Body__c = 'eDiscovery Association', Year_Text__c = '2023', Timekeeper__c = tk.get('Jamie Brooks'), Expiration_Date__c = today.addMonths(2)),
    new Skill_Certification__c(Name = 'Notary Public', Type__c = 'Certification', Year_Text__c = '2024', Timekeeper__c = tk.get('Casey Ford'), Expiration_Date__c = today.addYears(3))
};

// 6. Focus matters for the current user
for (Matter__c x : new List<Matter__c>{ lit, pi, panel, appeal }) FocusMatterService.toggle(x.Id);

// 7. Monthly retainer on the Meridian matter; generate this month's fee
Matter_Fee_Arrangement__c retainer = [SELECT Id FROM Matter_Fee_Arrangement__c WHERE Matter__c = :corp.Id LIMIT 1];
update new Matter_Fee_Arrangement__c(Id = retainer.Id, Fee_Arrangement_Price__c = 2500, Recurrence__c = 'Monthly', NextBillDate__c = today.toStartOfMonth(),
    Description__c = 'Monthly general counsel retainer, plus hourly work at 10% off.');
Integer recurring = RecurrenceService.generateDue(today);

// 8. Log Time from activities, and lock exported time
insert new List<Task>{
    new Task(WhatId = lit.Id, OwnerId = me, Subject = 'Call with client GC on mediation strategy', ActivityDate = today, Status = 'Completed', Time_in_Hours__c = 0.7),
    new Task(WhatId = panel.Id, OwnerId = me, Subject = 'Report to carrier on liability', ActivityDate = today.addDays(-1), Status = 'Completed', Time_in_Hours__c = 1.2,
        Description = 'Summarised discovery to date and recommended early mediation.')
};
List<Time__c> exported = [SELECT Id FROM Time__c WHERE Matter__c = :pi.Id ORDER BY Entry_Date__c LIMIT 2];
for (Time__c t : exported) t.Exported__c = true;
update exported;

// 9. Activity plan dependency: the demand letter follows the medical records request
Map<String, Activity_Plan_Template_Item__c> piSteps = new Map<String, Activity_Plan_Template_Item__c>();
for (Activity_Plan_Template_Item__c s : [SELECT Id, Subject__c FROM Activity_Plan_Template_Item__c WHERE Activity_Plan_Template__r.Type__c = 'Personal Injury']) piSteps.put(s.Subject__c, s);
update new Activity_Plan_Template_Item__c(Id = piSteps.get('Draft demand letter').Id, Depends_On__c = piSteps.get('Request medical records and bills').Id, Days_After_Dependency__c = 40);

// 10. Theo Grant intake: conflict check, then submit for approval
Intake__c theo = [SELECT Id FROM Intake__c WHERE Name LIKE 'Theo Grant%' LIMIT 1];
ConflictSearchService.checkIntake(theo.Id);
update new Intake__c(Id = theo.Id, Approver__c = me, Estimated_Value__c = 60000);
Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
req.setObjectId(theo.Id);
req.setComments('Slip and fall on transit platform. Conflict check clear.');
Approval.ProcessResult pr = Approval.process(req);

// 11. Rebuild transactions for all matters
Integer tx = TransactionService.rebuild(new Map<Id, Matter__c>([SELECT Id FROM Matter__c]).keySet());
System.debug('Step 5 done: ' + litDetails + '+' + empDetails + ' budget details, ' + recurring + ' recurring fee(s), approval ' + pr.getInstanceStatus()
    + ', ' + tx + ' transactions. SOQL ' + Limits.getQueries() + ', DML ' + Limits.getDmlStatements());
