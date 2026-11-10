/**
 * Matter automation:
 *  - defaults open date / status, stamps close date
 *  - blocks closing or deleting a matter on legal hold
 *  - keeps Participant rows in sync with the client, contact, attorney and paralegal lookups
 *  - creates legal hold acknowledgements when a hold is placed, releases them when it is lifted
 */
public with sharing class MatterTriggerHandler {

    public static void beforeInsert(List<Matter__c> rows) {
        for (Matter__c m : rows) {
            if (m.Open_Date__c == null) {
                m.Open_Date__c = Date.today();
            }
            if (m.Status__c == null) {
                m.Status__c = 'Open';
            }
            if (m.Status__c == 'Closed' && m.Close_Date__c == null) {
                m.Close_Date__c = Date.today();
            }
        }
    }

    public static void beforeUpdate(List<Matter__c> rows, Map<Id, Matter__c> oldMap) {
        for (Matter__c m : rows) {
            Matter__c old = oldMap.get(m.Id);
            if (m.Status__c == 'Closed' && old.Status__c != 'Closed') {
                if (m.Legal_Hold__c) {
                    m.addError('A matter on legal hold cannot be closed. Release the hold first.');
                } else if (m.Close_Date__c == null) {
                    m.Close_Date__c = Date.today();
                }
            }
        }
    }

    public static void beforeDelete(List<Matter__c> rows) {
        Set<Id> ids = new Map<Id, Matter__c>(rows).keySet();
        Set<Id> held = LegalHoldGuard.mattersOnHold(ids);
        Set<Id> withDefaults = RateTriggerHandler.mattersWithDefaultRates(ids);
        for (Matter__c m : rows) {
            if (held.contains(m.Id)) {
                m.addError('A matter on legal hold cannot be deleted. Release the hold first.');
            } else if (withDefaults.contains(m.Id)) {
                m.addError('This matter has default rates. Remove the default flag or delete those rates first.');
            }
        }
    }

    /** Sets the Participant record type (Account / Contact / User / Other) from the populated lookup. */
    public static void assignParticipantRecordTypes(List<Participant__c> rows) {
        Map<String, Schema.RecordTypeInfo> rts = Participant__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        for (Participant__c p : rows) {
            String dev = p.Staff__c != null ? 'User' : (p.Contact__c != null ? 'Contact' : (p.Account__c != null ? 'Account' : 'Other'));
            Schema.RecordTypeInfo rt = rts.get(dev);
            if (rt != null && rt.isAvailable()) {
                p.RecordTypeId = rt.getRecordTypeId();
            }
        }
    }

    public static void afterSave(List<Matter__c> rows, Map<Id, Matter__c> oldMap) {
        syncParticipants(rows, oldMap);
        handleLegalHold(rows, oldMap);
    }

    private static void syncParticipants(List<Matter__c> rows, Map<Id, Matter__c> oldMap) {
        List<Participant__c> wanted = new List<Participant__c>();
        for (Matter__c m : rows) {
            Matter__c old = oldMap == null ? null : oldMap.get(m.Id);
            if (m.Primary_Account__c != null && (old == null || old.Primary_Account__c != m.Primary_Account__c)) {
                wanted.add(new Participant__c(Matter__c = m.Id, Account__c = m.Primary_Account__c, Role__c = 'Client', Auto_Added__c = true));
            }
            if (m.Primary_Contact__c != null && (old == null || old.Primary_Contact__c != m.Primary_Contact__c)) {
                wanted.add(new Participant__c(Matter__c = m.Id, Contact__c = m.Primary_Contact__c, Role__c = 'Client', Auto_Added__c = true));
            }
            if (m.Responsible_Attorney__c != null && (old == null || old.Responsible_Attorney__c != m.Responsible_Attorney__c)) {
                wanted.add(new Participant__c(Matter__c = m.Id, Staff__c = m.Responsible_Attorney__c, Role__c = 'Responsible Attorney', Auto_Added__c = true));
            }
            if (m.Paralegal__c != null && (old == null || old.Paralegal__c != m.Paralegal__c)) {
                wanted.add(new Participant__c(Matter__c = m.Id, Staff__c = m.Paralegal__c, Role__c = 'Paralegal', Auto_Added__c = true));
            }
        }
        if (wanted.isEmpty()) {
            return;
        }
        Set<Id> matterIds = new Set<Id>();
        for (Participant__c p : wanted) {
            matterIds.add(p.Matter__c);
        }
        Set<String> existing = new Set<String>();
        for (Participant__c p : [
            SELECT Matter__c, Account__c, Contact__c, Staff__c, Role__c
            FROM Participant__c
            WHERE Matter__c IN :matterIds
        ]) {
            existing.add(participantKey(p));
        }
        List<Participant__c> toInsert = new List<Participant__c>();
        for (Participant__c p : wanted) {
            String key = participantKey(p);
            if (!existing.contains(key)) {
                existing.add(key);
                toInsert.add(p);
            }
        }
        insert toInsert;
    }

    private static String participantKey(Participant__c p) {
        Id ref = p.Account__c != null ? p.Account__c : (p.Contact__c != null ? p.Contact__c : p.Staff__c);
        return p.Matter__c + '|' + ref + '|' + p.Role__c;
    }

    private static void handleLegalHold(List<Matter__c> rows, Map<Id, Matter__c> oldMap) {
        Set<Id> placed = new Set<Id>();
        Set<Id> released = new Set<Id>();
        for (Matter__c m : rows) {
            Boolean wasOn = oldMap != null && oldMap.get(m.Id).Legal_Hold__c;
            if (m.Legal_Hold__c && !wasOn) {
                placed.add(m.Id);
            } else if (!m.Legal_Hold__c && wasOn) {
                released.add(m.Id);
            }
        }
        if (!placed.isEmpty()) {
            Set<String> open = new Set<String>();
            for (Matter_Legal_Hold_Acknowledgement__c a : [
                SELECT Matter__c, Custodian_Contact__c, Custodian_User__c
                FROM Matter_Legal_Hold_Acknowledgement__c
                WHERE Matter__c IN :placed AND Status__c != 'Released'
            ]) {
                open.add(a.Matter__c + '|' + a.Custodian_Contact__c + '|' + a.Custodian_User__c);
            }
            List<Matter_Legal_Hold_Acknowledgement__c> acks = new List<Matter_Legal_Hold_Acknowledgement__c>();
            for (Participant__c p : [
                SELECT Matter__c, Contact__c, Staff__c
                FROM Participant__c
                WHERE Matter__c IN :placed AND (Contact__c != null OR Staff__c != null)
                    AND Role__c NOT IN ('Opposing Party', 'Opposing Counsel', 'Judge')
            ]) {
                String key = p.Matter__c + '|' + p.Contact__c + '|' + p.Staff__c;
                if (open.contains(key)) {
                    continue;
                }
                open.add(key);
                acks.add(new Matter_Legal_Hold_Acknowledgement__c(
                    Matter__c = p.Matter__c,
                    Custodian_Contact__c = p.Contact__c,
                    Custodian_User__c = p.Staff__c,
                    Status__c = 'Pending',
                    Notice_Sent__c = System.now()
                ));
            }
            insert acks;
        }
        LegalHoldService.notifyCallback(placed, released);
        if (!released.isEmpty()) {
            List<Matter_Legal_Hold_Acknowledgement__c> toRelease = [
                SELECT Id FROM Matter_Legal_Hold_Acknowledgement__c
                WHERE Matter__c IN :released AND Status__c != 'Released'
            ];
            for (Matter_Legal_Hold_Acknowledgement__c a : toRelease) {
                a.Status__c = 'Released';
                a.Released_On__c = System.now();
            }
            update toRelease;
        }
    }
}
