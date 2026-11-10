@IsTest
public class MatterTestDataFactory {

    public static Database.DMLOptions allowDuplicates() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.DuplicateRuleHeader.runAsCurrentUser = true;
        return dml;
    }

    public static Account account(String name) {
        Account a = new Account(Name = name);
        Database.insert(a, allowDuplicates());
        return a;
    }

    public static Contact contact(String first, String last, Id accountId) {
        Contact c = new Contact(FirstName = first, LastName = last, AccountId = accountId);
        Database.insert(c, allowDuplicates());
        return c;
    }

    public static Timekeeper__c timekeeper(String name, Decimal rate) {
        Timekeeper__c tk = new Timekeeper__c(Name = name, Default_Rate__c = rate, Cost_Rate__c = rate / 2,
            Level__c = 'Associate', Active__c = true, User__c = UserInfo.getUserId());
        insert tk;
        return tk;
    }

    public static Matter__c matter(String name, Id accountId, Id contactId) {
        Matter__c m = new Matter__c(Name = name, Primary_Account__c = accountId, Primary_Contact__c = contactId,
            Type__c = 'Commercial Litigation', Responsible_Attorney__c = UserInfo.getUserId());
        insert m;
        return m;
    }

    public static Matter_Fee_Arrangement__c feeArrangement(Id matterId, String feeType) {
        Matter_Fee_Arrangement__c a = new Matter_Fee_Arrangement__c(Matter__c = matterId, Fee_Type__c = feeType,
            Default_for_Fees__c = true, Default_for_Expenses__c = true);
        insert a;
        return a;
    }

    public static Time__c timeEntry(Id matterId, Id timekeeperId, Decimal hours) {
        Time__c t = new Time__c(Matter__c = matterId, Timekeeper__c = timekeeperId, Time_in_Hours__c = hours,
            Entry_Date__c = Date.today().addDays(-1), Narrative__c = 'Review documents');
        insert t;
        return t;
    }

    public static Expense__c expense(Id matterId, Decimal amount) {
        Expense__c e = new Expense__c(Matter__c = matterId, Amount__c = amount, Category__c = 'Court Filing Fee',
            Expense_Date__c = Date.today().addDays(-1), Description__c = 'Filing fee');
        insert e;
        return e;
    }
}
