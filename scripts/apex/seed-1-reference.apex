// Matter Management sample data, step 1 of 4: clients, contacts, timekeepers, rates,
// fee arrangements, UTBMS codes and activity plan templates.
// All names are fictional. Accounts and contacts are tagged in Description for clean-up.
String TAG = 'Matter Management sample data';
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
dml.DuplicateRuleHeader.runAsCurrentUser = true;

List<Account> accounts = new List<Account>{
    new Account(Name = 'Harborline Freight Co (Sample)', Description = TAG, Phone = '(555) 010-1100'),
    new Account(Name = 'Meridian Dental Group (Sample)', Description = TAG, Phone = '(555) 010-1200'),
    new Account(Name = 'Calloway Family Trust (Sample)', Description = TAG),
    new Account(Name = 'Northgate Builders LLC (Sample)', Description = TAG, Phone = '(555) 010-1400'),
    new Account(Name = 'Brightwater Software Inc (Sample)', Description = TAG, Phone = '(555) 010-1500'),
    new Account(Name = 'Summit Ridge Insurance (Sample)', Description = TAG, Phone = '(555) 010-1600'),
    new Account(Name = 'Riverside Court Reporting (Sample)', Description = TAG + ' - vendor'),
    new Account(Name = 'Keystone Medical Records (Sample)', Description = TAG + ' - vendor')
};
Database.insert(accounts, dml);
Map<String, Id> acc = new Map<String, Id>();
for (Account a : accounts) acc.put(a.Name.substringBefore(' ('), a.Id);

List<Contact> contacts = new List<Contact>{
    new Contact(FirstName = 'Dana', LastName = 'Whitfield', Title = 'General Counsel', AccountId = acc.get('Harborline Freight Co'), Email = 'dana.whitfield@example.com', Description = TAG),
    new Contact(FirstName = 'Priya', LastName = 'Raman', Title = 'Managing Partner', AccountId = acc.get('Meridian Dental Group'), Email = 'priya.raman@example.com', Description = TAG),
    new Contact(FirstName = 'Elena', LastName = 'Calloway', Title = 'Trustee', AccountId = acc.get('Calloway Family Trust'), Email = 'elena.calloway@example.com', Description = TAG),
    new Contact(FirstName = 'Marcus', LastName = 'Delgado', Title = 'Owner', AccountId = acc.get('Northgate Builders LLC'), Email = 'marcus.delgado@example.com', Description = TAG),
    new Contact(FirstName = 'Tom', LastName = 'Reyes', Title = 'VP People Operations', AccountId = acc.get('Brightwater Software Inc'), Email = 'tom.reyes@example.com', Description = TAG),
    new Contact(FirstName = 'Grace', LastName = 'Okafor', Title = 'Senior Claims Adjuster', AccountId = acc.get('Summit Ridge Insurance'), Email = 'grace.okafor@example.com', Description = TAG),
    new Contact(FirstName = 'Jordan', LastName = 'Pike', Title = 'Individual client', Email = 'jordan.pike@example.com', Description = TAG),
    new Contact(FirstName = 'Nina', LastName = 'Albright', Title = 'Records Custodian', AccountId = acc.get('Harborline Freight Co'), Email = 'nina.albright@example.com', Description = TAG)
};
Database.insert(contacts, dml);

Id me = UserInfo.getUserId();
List<Timekeeper__c> tks = new List<Timekeeper__c>{
    new Timekeeper__c(Name = 'Avery Collins', Level__c = 'Partner', Default_Rate__c = 550, Cost_Rate__c = 220, User__c = me, Email__c = 'avery.collins@example.com', Active__c = true),
    new Timekeeper__c(Name = 'Morgan Lee', Level__c = 'Senior Associate', Default_Rate__c = 425, Cost_Rate__c = 170, Email__c = 'morgan.lee@example.com', Active__c = true),
    new Timekeeper__c(Name = 'Sam Patel', Level__c = 'Associate', Default_Rate__c = 325, Cost_Rate__c = 130, Email__c = 'sam.patel@example.com', Active__c = true),
    new Timekeeper__c(Name = 'Riley Chen', Level__c = 'Associate', Default_Rate__c = 300, Cost_Rate__c = 120, Email__c = 'riley.chen@example.com', Active__c = true),
    new Timekeeper__c(Name = 'Jamie Brooks', Level__c = 'Paralegal', Default_Rate__c = 165, Cost_Rate__c = 60, Email__c = 'jamie.brooks@example.com', Active__c = true),
    new Timekeeper__c(Name = 'Casey Ford', Level__c = 'Legal Assistant', Default_Rate__c = 95, Cost_Rate__c = 40, Email__c = 'casey.ford@example.com', Active__c = true)
};
insert tks;

Rate_Group__c standard = new Rate_Group__c(Name = 'Standard Rates 2026', Description__c = 'Firm standard hourly rates for 2026.', Active__c = true);
Rate_Group__c panel = new Rate_Group__c(Name = 'Insurance Panel Rates 2026', Description__c = 'Negotiated rates for insurance defense panel work.', Active__c = true);
insert new List<Rate_Group__c>{ standard, panel };
Map<String, Decimal> panelRates = new Map<String, Decimal>{
    'Avery Collins' => 450, 'Morgan Lee' => 350, 'Sam Patel' => 275, 'Riley Chen' => 250, 'Jamie Brooks' => 140
};
List<Rate__c> rates = new List<Rate__c>();
for (Timekeeper__c tk : tks) {
    rates.add(new Rate__c(Timekeeper__c = tk.Id, Rate_Group__c = standard.Id, Hourly_Rate__c = tk.Default_Rate__c, Effective_Date__c = Date.newInstance(2026, 1, 1), Default__c = true));
    if (panelRates.containsKey(tk.Name)) {
        rates.add(new Rate__c(Timekeeper__c = tk.Id, Rate_Group__c = panel.Id, Hourly_Rate__c = panelRates.get(tk.Name), Effective_Date__c = Date.newInstance(2026, 1, 1)));
    }
}
insert rates;

insert new List<Fee_Arrangement__c>{
    new Fee_Arrangement__c(Name = 'Standard Hourly', Fee_Type__c = 'Hourly', Active__c = true, Description__c = 'Time billed monthly at the timekeeper rate.'),
    new Fee_Arrangement__c(Name = 'Personal Injury Contingency 33.3%', Fee_Type__c = 'Contingency', Contingency_Percentage__c = 33.33, Active__c = true, Description__c = 'Fee from recovery; costs invoiced as incurred.'),
    new Fee_Arrangement__c(Name = 'Uncontested Divorce Flat Fee', Fee_Type__c = 'Fixed Fee', Fee_Arrangement_Price__c = 4500, Active__c = true, Description__c = 'One fixed fee covering the uncontested process.'),
    new Fee_Arrangement__c(Name = 'Employment Defense Capped', Fee_Type__c = 'Capped Fee', Cap_Amount__c = 25000, Active__c = true, Description__c = 'Hourly up to an agreed cap through mediation.'),
    new Fee_Arrangement__c(Name = 'Corporate Retainer 10% Discount', Fee_Type__c = 'Retainer', Discount_Percentage__c = 10, Active__c = true, Description__c = 'Monthly retainer client; 10% off standard rates.')
};

insert new List<UTBMS_Code__c>{
    new UTBMS_Code__c(Name = 'L110', Description__c = 'Fact Investigation/Development', Code_Type__c = 'Task', Phase__c = 'L100 Case Assessment'),
    new UTBMS_Code__c(Name = 'L120', Description__c = 'Analysis/Strategy', Code_Type__c = 'Task', Phase__c = 'L100 Case Assessment'),
    new UTBMS_Code__c(Name = 'L210', Description__c = 'Pleadings', Code_Type__c = 'Task', Phase__c = 'L200 Pre-Trial Pleadings and Motions'),
    new UTBMS_Code__c(Name = 'L250', Description__c = 'Other Written Motions and Submissions', Code_Type__c = 'Task', Phase__c = 'L200 Pre-Trial Pleadings and Motions'),
    new UTBMS_Code__c(Name = 'L310', Description__c = 'Written Discovery', Code_Type__c = 'Task', Phase__c = 'L300 Discovery'),
    new UTBMS_Code__c(Name = 'L330', Description__c = 'Depositions', Code_Type__c = 'Task', Phase__c = 'L300 Discovery'),
    new UTBMS_Code__c(Name = 'A101', Description__c = 'Plan and prepare for', Code_Type__c = 'Activity'),
    new UTBMS_Code__c(Name = 'A103', Description__c = 'Draft/revise', Code_Type__c = 'Activity'),
    new UTBMS_Code__c(Name = 'A104', Description__c = 'Review/analyze', Code_Type__c = 'Activity'),
    new UTBMS_Code__c(Name = 'A106', Description__c = 'Communicate (with client)', Code_Type__c = 'Activity'),
    new UTBMS_Code__c(Name = 'E101', Description__c = 'Copying', Code_Type__c = 'Expense'),
    new UTBMS_Code__c(Name = 'E112', Description__c = 'Court fees', Code_Type__c = 'Expense'),
    new UTBMS_Code__c(Name = 'E115', Description__c = 'Deposition transcripts', Code_Type__c = 'Expense'),
    new UTBMS_Code__c(Name = 'E124', Description__c = 'Other', Code_Type__c = 'Expense')
};

Activity_Plan_Template__c pi = new Activity_Plan_Template__c(Name = 'Personal Injury Case Opening', Type__c = 'Personal Injury', Active__c = true, Description__c = 'First 45 days of a new injury claim.');
Activity_Plan_Template__c fam = new Activity_Plan_Template__c(Name = 'Family Law Matter Opening', Type__c = 'Family Law', Active__c = true, Description__c = 'Opening steps for divorce and custody matters.');
Activity_Plan_Template__c lit = new Activity_Plan_Template__c(Name = 'Commercial Litigation Opening', Type__c = 'Commercial Litigation', Active__c = true, Description__c = 'Opening steps for a new commercial dispute.');
Activity_Plan_Template__c emp = new Activity_Plan_Template__c(Name = 'Employment Matter Opening', Type__c = 'Employment', Active__c = true, Description__c = 'Opening steps for an employment claim defense.');
insert new List<Activity_Plan_Template__c>{ pi, fam, lit, emp };

List<Activity_Plan_Template_Item__c> steps = new List<Activity_Plan_Template_Item__c>();
void addStep(List<Activity_Plan_Template_Item__c> l, Id t, Integer ord, String subj, Integer days, String who, String pri) {
    l.add(new Activity_Plan_Template_Item__c(Activity_Plan_Template__c = t, Step_Order__c = ord, Subject__c = subj, Days_Offset__c = days, Assign_To__c = who, Priority__c = pri));
}
addStep(steps, pi.Id, 1, 'Send engagement letter and medical authorizations', 1, 'Responsible Attorney', 'High');
addStep(steps, pi.Id, 2, 'Calendar statute of limitations', 1, 'Paralegal', 'High');
addStep(steps, pi.Id, 3, 'Send letter of representation to insurer', 2, 'Responsible Attorney', 'Normal');
addStep(steps, pi.Id, 4, 'Request medical records and bills', 3, 'Paralegal', 'Normal');
addStep(steps, pi.Id, 5, 'Collect accident report and photos', 7, 'Paralegal', 'Normal');
addStep(steps, pi.Id, 6, 'Draft demand letter', 45, 'Responsible Attorney', 'Normal');
addStep(steps, fam.Id, 1, 'Send engagement letter', 1, 'Responsible Attorney', 'High');
addStep(steps, fam.Id, 2, 'Calendar mandatory waiting period', 2, 'Paralegal', 'High');
addStep(steps, fam.Id, 3, 'Collect financial disclosures', 10, 'Paralegal', 'Normal');
addStep(steps, fam.Id, 4, 'Draft petition', 14, 'Responsible Attorney', 'Normal');
addStep(steps, fam.Id, 5, 'Schedule mediation', 30, 'Responsible Attorney', 'Low');
addStep(steps, lit.Id, 1, 'Send engagement letter', 1, 'Responsible Attorney', 'High');
addStep(steps, lit.Id, 2, 'Calendar response deadline', 1, 'Paralegal', 'High');
addStep(steps, lit.Id, 3, 'Issue litigation hold notice to client', 2, 'Responsible Attorney', 'High');
addStep(steps, lit.Id, 4, 'Early case assessment memo', 14, 'Responsible Attorney', 'Normal');
addStep(steps, lit.Id, 5, 'Prepare initial disclosures', 30, 'Responsible Attorney', 'Normal');
addStep(steps, emp.Id, 1, 'Send engagement letter', 1, 'Responsible Attorney', 'High');
addStep(steps, emp.Id, 2, 'Calendar agency response deadline', 2, 'Paralegal', 'High');
addStep(steps, emp.Id, 3, 'Collect personnel file and policies', 5, 'Paralegal', 'Normal');
addStep(steps, emp.Id, 4, 'Interview witnesses', 14, 'Responsible Attorney', 'Normal');
insert steps;

System.debug('Step 1 done: ' + accounts.size() + ' accounts, ' + contacts.size() + ' contacts, ' + tks.size() + ' timekeepers, ' + rates.size() + ' rates, ' + steps.size() + ' plan steps.');
