/**
 * Blocks changes that would destroy evidence while a matter (or its parent) is on legal hold.
 */
public with sharing class LegalHoldGuard {
    public static final String HOLD_MESSAGE =
        'This record belongs to a matter on legal hold and cannot be deleted. Release the hold first.';

    public static Set<Id> mattersOnHold(Set<Id> matterIds) {
        Set<Id> held = new Set<Id>();
        if (matterIds == null || matterIds.isEmpty()) {
            return held;
        }
        for (Matter__c m : [
            SELECT Id, Legal_Hold__c, Parent_Matter__r.Legal_Hold__c
            FROM Matter__c
            WHERE Id IN :matterIds
        ]) {
            if (m.Legal_Hold__c || m.Parent_Matter__r?.Legal_Hold__c == true) {
                held.add(m.Id);
            }
        }
        return held;
    }

    public static void blockDeletes(List<SObject> records, String matterField) {
        Set<Id> matterIds = new Set<Id>();
        for (SObject r : records) {
            Id matterId = (Id) r.get(matterField);
            if (matterId != null) {
                matterIds.add(matterId);
            }
        }
        Set<Id> held = mattersOnHold(matterIds);
        for (SObject r : records) {
            if (held.contains((Id) r.get(matterField))) {
                r.addError(HOLD_MESSAGE);
            }
        }
    }
}
