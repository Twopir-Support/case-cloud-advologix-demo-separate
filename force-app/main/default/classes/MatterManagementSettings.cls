/** Reads the Matter Management Settings hierarchy custom setting (per user, profile or org). */
public with sharing class MatterManagementSettings {
    @TestVisible private static Matter_Management_Settings__c testOverride;

    public static Matter_Management_Settings__c get() {
        if (testOverride != null) {
            return testOverride;
        }
        Matter_Management_Settings__c s = Matter_Management_Settings__c.getInstance();
        return s == null ? new Matter_Management_Settings__c(Send_Legal_Hold_Emails__c = true) : s;
    }

    /** True when the named switch (for example 'Disable_Matter_Trigger__c') is on. */
    public static Boolean isDisabled(String switchField) {
        Object v = get().get(switchField);
        return v == true;
    }
}
