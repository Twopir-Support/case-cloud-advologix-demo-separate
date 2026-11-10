/** Settlement Calculator defaults: contingency %, case costs and the latest offer or demand on the matter. */
public with sharing class SettlementCalculatorController {

    @AuraEnabled
    public static Map<String, Object> getDefaults(Id matterId) {
        Matter__c m = [SELECT Id, Name, Total_Expenses__c FROM Matter__c WHERE Id = :matterId];
        List<Matter_Fee_Arrangement__c> mfa = [SELECT Contingency_Percentage__c, Fee_Type__c FROM Matter_Fee_Arrangement__c
                                               WHERE Matter__c = :matterId AND Default_for_Fees__c = true LIMIT 1];
        List<Offer_and_Demand__c> od = [SELECT Amount__c, Type__c, Status__c FROM Offer_and_Demand__c WHERE Matter__c = :matterId
                                        ORDER BY Date__c DESC NULLS LAST, CreatedDate DESC LIMIT 1];
        Decimal billedCosts = 0;
        for (AggregateResult ar : [SELECT SUM(Expenses_Subtotal__c) s, SUM(Amount_Paid__c) p FROM Invoice__c WHERE Matter__c = :matterId AND Status__c != 'Void']) {
            billedCosts = ar.get('p') == null ? 0 : (Decimal) ar.get('p');
        }
        return new Map<String, Object>{
            'matterName' => m.Name,
            'contingencyPercent' => mfa.isEmpty() || mfa[0].Contingency_Percentage__c == null ? 33.33 : mfa[0].Contingency_Percentage__c,
            'feeType' => mfa.isEmpty() ? null : mfa[0].Fee_Type__c,
            'caseCosts' => m.Total_Expenses__c == null ? 0 : m.Total_Expenses__c,
            'costsAlreadyPaid' => billedCosts,
            'grossSettlement' => od.isEmpty() ? 0 : od[0].Amount__c,
            'offerLabel' => od.isEmpty() ? null : od[0].Type__c + ' (' + od[0].Status__c + ')'
        };
    }
}
