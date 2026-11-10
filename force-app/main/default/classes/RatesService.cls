/**
 * Rates.
 *
 * Public API (same shape as the CaseCloud RatesService):
 *   String json = RatesService.copyRates(fromMatterId, fromRateGroupId, toMatterId, copyDefaultFlag);
 *     fromMatterId / fromRateGroupId  one is required; if both are given, only timekeepers with a rate in both are copied
 *     toMatterId                      required, the matter that receives the rates
 *     copyDefaultFlag                 true keeps the source Default flag, otherwise copies are not default
 *     returns JSON                    {"success": true|false, "result": "<message>"}
 */
public with sharing class RatesService {
    public class RatesException extends Exception {}

    public class Request {
        @InvocableVariable(required=true label='To Matter ID')
        public Id toMatterId;
        @InvocableVariable(label='From Matter ID')
        public Id fromMatterId;
        @InvocableVariable(label='From Rate Group ID')
        public Id fromRateGroupId;
        @InvocableVariable(label='Copy Default Flag')
        public Boolean copyDefaultFlag;
    }

    public static String copyRates(Id fromMatterId, Id fromRateGroupId, Id toMatterId, Boolean copyDefaultFlag) {
        Map<String, Object> out = new Map<String, Object>();
        try {
            Integer n = copy(fromMatterId, fromRateGroupId, toMatterId, copyDefaultFlag == true);
            out.put('success', true);
            out.put('result', n + ' rate(s) copied.');
        } catch (Exception e) {
            out.put('success', false);
            out.put('result', e.getMessage());
        }
        return JSON.serialize(out);
    }

    @InvocableMethod(label='Copy Rates' description='Copies timekeeper rates from a matter and/or rate group to another matter.' category='Matter Management')
    public static List<String> copyFromFlow(List<Request> requests) {
        List<String> results = new List<String>();
        for (Request r : requests) {
            results.add(copyRates(r.fromMatterId, r.fromRateGroupId, r.toMatterId, r.copyDefaultFlag));
        }
        return results;
    }

    private static Integer copy(Id fromMatterId, Id fromRateGroupId, Id toMatterId, Boolean copyDefault) {
        if (toMatterId == null) {
            throw new RatesException('To Matter ID is required.');
        }
        if (fromMatterId == null && fromRateGroupId == null) {
            throw new RatesException('Provide a From Matter ID, a From Rate Group ID, or both.');
        }
        Map<Id, Rate__c> byMatter = latestByTimekeeper(fromMatterId, null);
        Map<Id, Rate__c> byGroup = latestByTimekeeper(null, fromRateGroupId);
        Map<Id, Rate__c> source;
        if (fromMatterId != null && fromRateGroupId != null) {
            source = new Map<Id, Rate__c>();
            for (Id tk : byMatter.keySet()) {
                if (byGroup.containsKey(tk)) {
                    source.put(tk, byMatter.get(tk));
                }
            }
        } else {
            source = fromMatterId != null ? byMatter : byGroup;
        }
        List<Rate__c> copies = new List<Rate__c>();
        for (Rate__c r : source.values()) {
            copies.add(new Rate__c(Matter__c = toMatterId, Timekeeper__c = r.Timekeeper__c, Hourly_Rate__c = r.Hourly_Rate__c,
                Effective_Date__c = r.Effective_Date__c, Default__c = copyDefault && r.Default__c));
        }
        insert copies;
        return copies.size();
    }

    private static Map<Id, Rate__c> latestByTimekeeper(Id matterId, Id rateGroupId) {
        Map<Id, Rate__c> result = new Map<Id, Rate__c>();
        if (matterId == null && rateGroupId == null) {
            return result;
        }
        List<Rate__c> rates = matterId != null
            ? [SELECT Timekeeper__c, Hourly_Rate__c, Effective_Date__c, Default__c FROM Rate__c WHERE Matter__c = :matterId ORDER BY Effective_Date__c DESC NULLS LAST]
            : [SELECT Timekeeper__c, Hourly_Rate__c, Effective_Date__c, Default__c FROM Rate__c WHERE Rate_Group__c = :rateGroupId AND Matter__c = null ORDER BY Effective_Date__c DESC NULLS LAST];
        for (Rate__c r : rates) {
            if (r.Timekeeper__c != null && !result.containsKey(r.Timekeeper__c)) {
                result.put(r.Timekeeper__c, r);
            }
        }
        return result;
    }
}
