// Matter Management sample data, step 4 of 4: time entries, expenses, invoices, a payment,
// and a legal hold with custodian acknowledgements.
Date today = Date.today();
Map<String, Id> tk = new Map<String, Id>();
for (Timekeeper__c x : [SELECT Id, Name FROM Timekeeper__c]) tk.put(x.Name, x.Id);
Map<String, Id> code = new Map<String, Id>();
for (UTBMS_Code__c c : [SELECT Id, Name FROM UTBMS_Code__c]) code.put(c.Name, c.Id);
Map<String, Id> acc = new Map<String, Id>();
for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE '% (Sample)']) acc.put(a.Name.substringBefore(' ('), a.Id);
Map<String, Matter__c> m = new Map<String, Matter__c>();
for (Matter__c x : [SELECT Id, Name, Type__c, Parent_Matter__c, Rate_Group__r.Name FROM Matter__c]) {
    String key = x.Type__c;
    if (x.Parent_Matter__c != null) key = 'Appeal';
    else if (x.Rate_Group__r?.Name == 'Insurance Panel Rates 2026') key = 'Panel';
    m.put(key, x);
}

class TimeBuilder {
    Map<String, Id> tks; Map<String, Id> codes;
    List<Time__c> rows = new List<Time__c>();
    TimeBuilder(Map<String, Id> tks, Map<String, Id> codes) { this.tks = tks; this.codes = codes; }
    void add(Matter__c mt, String who, Integer daysAgo, Decimal hrs, String task, String act, String narrative) {
        rows.add(new Time__c(Matter__c = mt.Id, Timekeeper__c = tks.get(who), Entry_Date__c = Date.today().addDays(-daysAgo), Time_in_Hours__c = hrs,
            Task_Code__c = task == null ? null : codes.get(task), Activity_Code__c = act == null ? null : codes.get(act), Narrative__c = narrative));
    }
}
TimeBuilder b = new TimeBuilder(tk, code);
// Personal injury (contingency: time is tracked but not invoiced)
b.add(m.get('Personal Injury'), 'Avery Collins', 33, 1.5, 'L110', 'A106', 'Initial client meeting; reviewed accident facts and treatment to date.');
b.add(m.get('Personal Injury'), 'Jamie Brooks', 30, 2.0, 'L110', 'A104', 'Requested and indexed ER and orthopedic records.');
b.add(m.get('Personal Injury'), 'Sam Patel', 20, 3.2, 'L120', 'A103', 'Drafted liability analysis memo for demand strategy.');
b.add(m.get('Personal Injury'), 'Jamie Brooks', 4, 1.0, 'L110', 'A104', 'Updated medical specials spreadsheet with new bills.');
// Family law (fixed fee)
b.add(m.get('Family Law'), 'Morgan Lee', 31, 1.2, null, 'A106', 'Consultation on settlement terms and timeline.');
b.add(m.get('Family Law'), 'Morgan Lee', 22, 2.5, null, 'A103', 'Drafted marital settlement agreement.');
b.add(m.get('Family Law'), 'Casey Ford', 15, 1.0, null, 'A101', 'Prepared financial disclosure packet for filing.');
// Commercial litigation (hourly)
b.add(m.get('Commercial Litigation'), 'Avery Collins', 30, 2.0, 'L120', 'A101', 'Case strategy session with client general counsel.');
b.add(m.get('Commercial Litigation'), 'Riley Chen', 28, 4.5, 'L210', 'A103', 'Drafted complaint for breach of warehousing agreement.');
b.add(m.get('Commercial Litigation'), 'Avery Collins', 26, 1.5, 'L210', 'A104', 'Revised complaint; approved for filing.');
b.add(m.get('Commercial Litigation'), 'Riley Chen', 18, 3.8, 'L310', 'A103', 'Prepared first set of interrogatories and document requests.');
b.add(m.get('Commercial Litigation'), 'Jamie Brooks', 16, 2.5, 'L310', 'A104', 'Organised client inventory records for production.');
b.add(m.get('Commercial Litigation'), 'Morgan Lee', 6, 5.0, 'L330', 'A101', 'Prepared outline for deposition of opposing operations manager.');
b.add(m.get('Commercial Litigation'), 'Avery Collins', 2, 0.8, 'L120', 'A106', 'Call with client on settlement range ahead of mediation.');
// Employment (capped fee)
b.add(m.get('Employment'), 'Morgan Lee', 27, 3.0, 'L110', 'A104', 'Reviewed personnel file and termination documentation.');
b.add(m.get('Employment'), 'Sam Patel', 21, 6.5, 'L250', 'A103', 'Drafted position statement to the agency.');
b.add(m.get('Employment'), 'Morgan Lee', 19, 2.0, 'L250', 'A104', 'Revised position statement; client review call.');
// Corporate (retainer, 10% discount)
b.add(m.get('Corporate & Transactions'), 'Avery Collins', 27, 2.0, null, 'A106', 'Kick-off call on deal structure and timeline.');
b.add(m.get('Corporate & Transactions'), 'Riley Chen', 24, 6.0, null, 'A104', 'Due diligence review of seller leases and payer contracts.');
b.add(m.get('Corporate & Transactions'), 'Riley Chen', 17, 5.5, null, 'A103', 'Drafted asset purchase agreement, first turn.');
b.add(m.get('Corporate & Transactions'), 'Avery Collins', 12, 1.8, null, 'A104', 'Reviewed and marked up purchase agreement.');
// Real estate (hourly)
b.add(m.get('Real Estate'), 'Sam Patel', 25, 2.4, 'L110', 'A104', 'Reviewed lien notice, contract and payment history.');
b.add(m.get('Real Estate'), 'Sam Patel', 14, 3.1, 'L210', 'A103', 'Drafted complaint to foreclose mechanics lien.');
// Appeal (hourly, recent: stays as work in progress)
b.add(m.get('Appeal'), 'Morgan Lee', 10, 4.0, 'L250', 'A104', 'Reviewed trial record and summary judgment order.');
b.add(m.get('Appeal'), 'Riley Chen', 5, 6.0, 'L250', 'A103', 'Drafted statement of issues on appeal.');
// Panel defense (panel rates)
b.add(m.get('Panel'), 'Avery Collins', 24, 1.0, 'L120', 'A101', 'Initial case evaluation and report to carrier.');
b.add(m.get('Panel'), 'Sam Patel', 20, 4.2, 'L310', 'A103', 'Drafted responses to plaintiff interrogatories.');
b.add(m.get('Panel'), 'Jamie Brooks', 13, 3.0, 'L310', 'A104', 'Collected incident reports and maintenance logs from insured.');
b.add(m.get('Panel'), 'Sam Patel', 3, 2.6, 'L330', 'A101', 'Prepared insured for deposition.');
Time__c noCharge = new Time__c(Matter__c = m.get('Commercial Litigation').Id, Timekeeper__c = tk.get('Casey Ford'), Entry_Date__c = today.addDays(-15),
    Time_in_Hours__c = 0.5, Disposition__c = 'No Charge', Narrative__c = 'Internal file opening and conflict paperwork (courtesy, no charge).');
List<Time__c> times = b.rows;
times.add(noCharge);
insert times;

List<Expense__c> exps = new List<Expense__c>{
    new Expense__c(Matter__c = m.get('Personal Injury').Id, Expense_Date__c = today.addDays(-28), Category__c = 'Medical Records', Amount__c = 185, Vendor__c = acc.get('Keystone Medical Records'), Expense_Code__c = code.get('E124'), Description__c = 'ER and orthopedic records retrieval'),
    new Expense__c(Matter__c = m.get('Personal Injury').Id, Expense_Date__c = today.addDays(-26), Category__c = 'Other', Amount__c = 25, Expense_Code__c = code.get('E124'), Description__c = 'Police accident report'),
    new Expense__c(Matter__c = m.get('Family Law').Id, Expense_Date__c = today.addDays(-14), Category__c = 'Court Filing Fee', Amount__c = 435, Expense_Code__c = code.get('E112'), Description__c = 'Petition filing fee'),
    new Expense__c(Matter__c = m.get('Commercial Litigation').Id, Expense_Date__c = today.addDays(-25), Category__c = 'Court Filing Fee', Amount__c = 450, Expense_Code__c = code.get('E112'), Description__c = 'Complaint filing fee'),
    new Expense__c(Matter__c = m.get('Commercial Litigation').Id, Expense_Date__c = today.addDays(-24), Category__c = 'Courier', Amount__c = 95, Expense_Code__c = code.get('E124'), Description__c = 'Service of process'),
    new Expense__c(Matter__c = m.get('Commercial Litigation').Id, Expense_Date__c = today.addDays(-4), Category__c = 'Deposition / Transcript', Amount__c = 1240, Vendor__c = acc.get('Riverside Court Reporting'), Expense_Code__c = code.get('E115'), Description__c = 'Court reporter deposit for operations manager deposition'),
    new Expense__c(Matter__c = m.get('Employment').Id, Expense_Date__c = today.addDays(-20), Category__c = 'Copying & Printing', Amount__c = 62.40, Expense_Code__c = code.get('E101'), Description__c = 'Exhibit binders for position statement'),
    new Expense__c(Matter__c = m.get('Corporate & Transactions').Id, Expense_Date__c = today.addDays(-22), Category__c = 'Other', Amount__c = 310, Expense_Code__c = code.get('E124'), Description__c = 'Lien and UCC searches'),
    new Expense__c(Matter__c = m.get('Real Estate').Id, Expense_Date__c = today.addDays(-13), Category__c = 'Court Filing Fee', Amount__c = 400, Expense_Code__c = code.get('E112'), Description__c = 'Lien foreclosure filing fee'),
    new Expense__c(Matter__c = m.get('Panel').Id, Expense_Date__c = today.addDays(-11), Category__c = 'Travel', Amount__c = 148.75, Expense_Code__c = code.get('E124'), Description__c = 'Mileage for site inspection', Disposition__c = 'Do Not Bill'),
    new Expense__c(Matter__c = m.get('Appeal').Id, Expense_Date__c = today.addDays(-9), Category__c = 'Deposition / Transcript', Amount__c = 680, Vendor__c = acc.get('Riverside Court Reporting'), Expense_Code__c = code.get('E115'), Description__c = 'Trial transcript for appellate record')
};
insert exps;

// Invoices billed through 7 days ago, so the most recent work stays as WIP
Date cutoff = today.addDays(-7);
Id litInv = BillingService.createInvoice(m.get('Commercial Litigation').Id, cutoff);
Id famInv = BillingService.createInvoice(m.get('Family Law').Id, cutoff);
Id corpInv = BillingService.createInvoice(m.get('Corporate & Transactions').Id, cutoff);
Id empInv = BillingService.createInvoice(m.get('Employment').Id, cutoff);
Id piInv = BillingService.createInvoice(m.get('Personal Injury').Id, cutoff);

Invoice__c corp = [SELECT Id, Total_Amount__c FROM Invoice__c WHERE Id = :corpInv];
update new List<Invoice__c>{
    new Invoice__c(Id = corpInv, Status__c = 'Paid', Amount_Paid__c = corp.Total_Amount__c, Notes__c = 'Paid by ACH.'),
    new Invoice__c(Id = famInv, Status__c = 'Sent'),
    new Invoice__c(Id = litInv, Status__c = 'Approved'),
    new Invoice__c(Id = piInv, Status__c = 'Sent', Notes__c = 'Costs only. Fees are contingent on recovery.')
};

// Legal hold on the panel defense matter
update new Matter__c(Id = m.get('Panel').Id, Legal_Hold__c = true);
List<Matter_Legal_Hold_Acknowledgement__c> acks = [SELECT Id FROM Matter_Legal_Hold_Acknowledgement__c WHERE Matter__c = :m.get('Panel').Id ORDER BY Name LIMIT 1];
for (Matter_Legal_Hold_Acknowledgement__c a : acks) {
    a.Status__c = 'Acknowledged';
    a.Acknowledged_On__c = System.now();
}
update acks;

System.debug('Step 4 done: ' + times.size() + ' time entries, ' + exps.size() + ' expenses, 5 invoices. SOQL used: ' + Limits.getQueries());
