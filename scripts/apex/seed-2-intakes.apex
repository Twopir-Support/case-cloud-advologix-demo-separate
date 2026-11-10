// Matter Management sample data, step 2 of 4: intakes and their conflict checks.
Map<String, Id> acc = new Map<String, Id>();
for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE '% (Sample)']) acc.put(a.Name.substringBefore(' ('), a.Id);
Map<String, Id> con = new Map<String, Id>();
for (Contact c : [SELECT Id, Name FROM Contact WHERE Name IN ('Dana Whitfield','Priya Raman','Elena Calloway','Marcus Delgado','Tom Reyes','Grace Okafor','Jordan Pike','Nina Albright') AND Email LIKE '%@example.com']) con.put(c.Name, c.Id);
Id me = UserInfo.getUserId();
Date today = Date.today();

List<Intake__c> intakes = new List<Intake__c>{
    new Intake__c(Name = 'Jordan Pike - Auto Accident', Primary_Contact__c = con.get('Jordan Pike'), Type__c = 'Personal Injury',
        Source__c = 'Referral', Adverse_Party__c = 'Rowan Haulage Ltd', Incident_Date__c = today.addDays(-75), Start_Date__c = today.addDays(-40),
        Estimated_Value__c = 250000, Approver__c = me, Status__c = 'Submitted',
        Description__c = 'Rear-end collision with a commercial truck. Client treated for neck and back injuries; ongoing physiotherapy.'),
    new Intake__c(Name = 'Calloway - Uncontested Divorce', Primary_Account__c = acc.get('Calloway Family Trust'), Primary_Contact__c = con.get('Elena Calloway'),
        Type__c = 'Family Law', Source__c = 'Phone', Adverse_Party__c = 'Victor Calloway', Start_Date__c = today.addDays(-38),
        Approver__c = me, Status__c = 'Submitted', Description__c = 'Uncontested divorce; parties have agreed terms on property and parenting time.'),
    new Intake__c(Name = 'Harborline Freight v. Coastal Warehousing', Primary_Account__c = acc.get('Harborline Freight Co'), Primary_Contact__c = con.get('Dana Whitfield'),
        Type__c = 'Commercial Litigation', Source__c = 'Email', Adverse_Party__c = 'Coastal Warehousing Partners', Start_Date__c = today.addDays(-36),
        Estimated_Value__c = 1200000, Approver__c = me, Status__c = 'Submitted',
        Description__c = 'Breach of a warehousing services agreement; client claims lost inventory and consequential damages.'),
    new Intake__c(Name = 'Brightwater Software - Morgan Agency Charge', Primary_Account__c = acc.get('Brightwater Software Inc'), Primary_Contact__c = con.get('Tom Reyes'),
        Type__c = 'Employment', Source__c = 'Email', Adverse_Party__c = 'Leah Morgan', Start_Date__c = today.addDays(-34),
        Approver__c = me, Status__c = 'Submitted', Description__c = 'Former employee filed an agency charge alleging retaliatory termination.'),
    new Intake__c(Name = 'Meridian Dental - Lakeview Practice Acquisition', Primary_Account__c = acc.get('Meridian Dental Group'), Primary_Contact__c = con.get('Priya Raman'),
        Type__c = 'Corporate & Transactions', Source__c = 'Referral', Adverse_Party__c = 'Lakeview Dental PC', Start_Date__c = today.addDays(-33),
        Estimated_Value__c = 3500000, Approver__c = me, Status__c = 'Submitted', Description__c = 'Acquisition of a two-location dental practice: diligence, purchase agreement and closing.'),
    new Intake__c(Name = 'Northgate Builders - Elmstead Lien', Primary_Account__c = acc.get('Northgate Builders LLC'), Primary_Contact__c = con.get('Marcus Delgado'),
        Type__c = 'Real Estate', Source__c = 'Web Form', Adverse_Party__c = 'Elmstead Property Holdings', Start_Date__c = today.addDays(-30),
        Estimated_Value__c = 180000, Approver__c = me, Status__c = 'Submitted', Description__c = 'Mechanics lien enforcement for unpaid work on a mixed-use building.'),
    new Intake__c(Name = 'Ashford Logistics v. Harborline Freight', Type__c = 'Commercial Litigation', Source__c = 'Web Form',
        Adverse_Party__c = 'Harborline Freight Co (Sample)', Start_Date__c = today.addDays(-3), Estimated_Value__c = 400000, Approver__c = me, Status__c = 'Requested',
        Description__c = 'Prospective client wants to sue Harborline Freight over a missed delivery contract. Existing client conflict expected.'),
    new Intake__c(Name = 'Theo Grant - Transit Platform Fall', Type__c = 'Personal Injury', Source__c = 'Walk-in', Adverse_Party__c = 'City Transit Authority',
        Incident_Date__c = today.addDays(-10), Start_Date__c = today.addDays(-1), Status__c = 'Requested',
        Description__c = 'Slip and fall on a bus platform. Awaiting photos and incident report.'),
    new Intake__c(Name = 'Quinn Hollis - Visa Renewal', Type__c = 'Immigration', Source__c = 'Phone', Start_Date__c = today.addDays(-20),
        Status__c = 'Rejected', Conflict_Status__c = 'Not Run', Description__c = 'Visa renewal question. Declined: outside the firm\'s current practice areas; referred out.')
};
insert intakes;

// Conflict checks on the six intakes that will be accepted
Integer n = 0;
for (Intake__c i : intakes) {
    if (i.Status__c == 'Submitted') {
        ConflictSearchService.checkIntake(i.Id);
        n++;
    }
}
System.debug('Step 2 done: ' + intakes.size() + ' intakes, ' + n + ' conflict checks run. SOQL used: ' + Limits.getQueries());
