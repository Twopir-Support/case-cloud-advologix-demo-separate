/**
 * Recurring fees: for each Matter Fee Arrangement (Retainer or Fixed Fee) with Recurrence Monthly or Quarterly
 * and a Next Bill Date on or before today, creates Recurrence Transactions and advances the Next Bill Date.
 * Billing picks up unprocessed Recurrence Transactions as fee lines.
 * Schedule daily: System.schedule('Matter Management Recurring Fees', '0 30 0 * * ?', new RecurrenceService());
 */
public with sharing class RecurrenceService implements Schedulable {

    public void execute(SchedulableContext sc) {
        generateDue(Date.today());
    }

    @InvocableMethod(label='Generate Recurring Fees' description='Creates recurrence transactions that are due today.' category='Matter Management')
    public static List<Integer> generateFromFlow(List<Date> asOf) {
        return new List<Integer>{ generateDue(asOf == null || asOf.isEmpty() || asOf[0] == null ? Date.today() : asOf[0]) };
    }

    public static Integer generateDue(Date asOf) {
        List<Matter_Fee_Arrangement__c> mfas = [
            SELECT Id, Matter__c, Matter__r.Primary_Account__c, Matter__r.Name, Source_Fee_Arrangement__c, Fee_Arrangement_Price__c,
                   Recurrence__c, NextBillDate__c, End_Date__c, Fee_Type__c
            FROM Matter_Fee_Arrangement__c
            WHERE Recurrence__c IN ('Monthly', 'Quarterly') AND Fee_Type__c IN ('Retainer', 'Fixed Fee')
                AND Fee_Arrangement_Price__c > 0 AND NextBillDate__c != null AND NextBillDate__c <= :asOf
        ];
        List<Recurrence_Transaction__c> txs = new List<Recurrence_Transaction__c>();
        for (Matter_Fee_Arrangement__c a : mfas) {
            Integer step = a.Recurrence__c == 'Quarterly' ? 3 : 1;
            Date next = a.NextBillDate__c;
            Integer guard = 0;
            while (next <= asOf && (a.End_Date__c == null || next <= a.End_Date__c) && guard < 36) {
                txs.add(new Recurrence_Transaction__c(Matter__c = a.Matter__c, Matter_Fee_Arrangement__c = a.Id,
                    Source_Fee_Arrangement__c = a.Source_Fee_Arrangement__c, Account__c = a.Matter__r.Primary_Account__c,
                    Transaction_Date__c = next, Amount__c = a.Fee_Arrangement_Price__c, Status__c = 'Unprocessed',
                    Description__c = (a.Recurrence__c + ' ' + a.Fee_Type__c.toLowerCase() + ' fee for ' + next.month() + '/' + next.year()).left(255)));
                next = next.addMonths(step);
                guard++;
            }
            a.NextBillDate__c = next;
        }
        insert txs;
        update mfas;
        return txs.size();
    }
}
