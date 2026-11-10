/** Rate, rate group and timekeeper integrity rules. */
public with sharing class RateTriggerHandler {

    /** Only one default rate per timekeeper + matter + rate group. */
    public static void enforceSingleDefault(List<Rate__c> rows) {
        Set<Id> tkIds = new Set<Id>();
        Map<String, Rate__c> incoming = new Map<String, Rate__c>();
        for (Rate__c r : rows) {
            if (!r.Default__c) {
                continue;
            }
            String key = r.Timekeeper__c + '|' + r.Matter__c + '|' + r.Rate_Group__c;
            if (incoming.containsKey(key)) {
                r.addError('Only one default rate is allowed for the same timekeeper, matter and rate group.');
            }
            incoming.put(key, r);
            tkIds.add(r.Timekeeper__c);
        }
        if (incoming.isEmpty()) {
            return;
        }
        for (Rate__c existing : [SELECT Id, Timekeeper__c, Matter__c, Rate_Group__c FROM Rate__c WHERE Default__c = true AND Timekeeper__c IN :tkIds]) {
            Rate__c r = incoming.get(existing.Timekeeper__c + '|' + existing.Matter__c + '|' + existing.Rate_Group__c);
            if (r != null && r.Id != existing.Id) {
                r.addError('A default rate already exists for this timekeeper, matter and rate group.');
            }
        }
    }

    public static void blockRateGroupDelete(List<Rate_Group__c> rows) {
        Set<Id> withRates = new Set<Id>();
        for (AggregateResult ar : [SELECT Rate_Group__c g FROM Rate__c WHERE Rate_Group__c IN :rows GROUP BY Rate_Group__c]) {
            withRates.add((Id) ar.get('g'));
        }
        for (Rate_Group__c g : rows) {
            if (withRates.contains(g.Id)) {
                g.addError('This rate group has rates. Delete or move its rates first.');
            }
        }
    }

    public static void blockTimekeeperDelete(List<Timekeeper__c> rows) {
        Set<Id> withDefaults = new Set<Id>();
        for (AggregateResult ar : [SELECT Timekeeper__c t FROM Rate__c WHERE Timekeeper__c IN :rows AND Default__c = true GROUP BY Timekeeper__c]) {
            withDefaults.add((Id) ar.get('t'));
        }
        for (Timekeeper__c t : rows) {
            if (withDefaults.contains(t.Id)) {
                t.addError('This timekeeper has default rates. Remove the default flag or delete those rates first.');
            }
        }
    }

    public static Set<Id> mattersWithDefaultRates(Set<Id> matterIds) {
        Set<Id> result = new Set<Id>();
        for (AggregateResult ar : [SELECT Matter__c m FROM Rate__c WHERE Matter__c IN :matterIds AND Default__c = true GROUP BY Matter__c]) {
            result.add((Id) ar.get('m'));
        }
        return result;
    }
}
