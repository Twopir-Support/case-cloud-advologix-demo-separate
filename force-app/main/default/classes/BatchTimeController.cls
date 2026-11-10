/** Batch Time: enter several time entries in one go. */
public with sharing class BatchTimeController {
    public class BatchTimeException extends Exception {}

    public class Row {
        @AuraEnabled public Id matterId;
        @AuraEnabled public Id timekeeperId;
        @AuraEnabled public Date entryDate;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public Id taskCodeId;
        @AuraEnabled public String narrative;
        @AuraEnabled public String disposition;
    }

    @AuraEnabled
    public static Map<String, Object> getContext() {
        List<Timekeeper__c> mine = [SELECT Id, Name FROM Timekeeper__c WHERE User__c = :UserInfo.getUserId() AND Active__c = true LIMIT 1];
        return new Map<String, Object>{
            'timekeeperId' => mine.isEmpty() ? null : mine[0].Id,
            'timekeeperName' => mine.isEmpty() ? null : mine[0].Name
        };
    }

    @AuraEnabled
    public static Integer saveEntries(String rowsJson) {
        try {
            List<Row> rows = (List<Row>) JSON.deserialize(rowsJson, List<Row>.class);
            List<Time__c> times = new List<Time__c>();
            Integer n = 0;
            for (Row r : rows) {
                n++;
                if (r.matterId == null || r.hours == null || r.hours <= 0 || r.timekeeperId == null) {
                    throw new BatchTimeException('Row ' + n + ': matter, timekeeper and hours are required.');
                }
                times.add(new Time__c(Name = 'Time', Matter__c = r.matterId, Timekeeper__c = r.timekeeperId,
                    Entry_Date__c = r.entryDate == null ? Date.today() : r.entryDate, Time_in_Hours__c = r.hours,
                    Task_Code__c = r.taskCodeId, Narrative__c = r.narrative,
                    Disposition__c = String.isBlank(r.disposition) ? 'Bill' : r.disposition));
            }
            insert times;
            return times.size();
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }
}
