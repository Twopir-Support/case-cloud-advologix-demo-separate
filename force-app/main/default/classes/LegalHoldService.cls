/** Legal hold notices, acknowledgements, the callback hook and file protection. */
public with sharing class LegalHoldService {

    @AuraEnabled
    public static void acknowledge(Id ackId) {
        try {
            Matter_Legal_Hold_Acknowledgement__c a = [SELECT Id, Status__c FROM Matter_Legal_Hold_Acknowledgement__c WHERE Id = :ackId];
            if (a.Status__c == 'Released') {
                throw new LegalHoldException('This legal hold has been released and no longer needs acknowledgement.');
            }
            a.Status__c = 'Acknowledged';
            a.Acknowledged_On__c = System.now();
            update a;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    public class LegalHoldException extends Exception {}

    /** Sends the legal hold notice to each custodian (contact or user). Returns the number of emails queued. */
    public static Integer sendNotices(List<Matter_Legal_Hold_Acknowledgement__c> acks) {
        if (!MatterManagementSettings.get().Send_Legal_Hold_Emails__c) {
            return 0;
        }
        Set<Id> matterIds = new Set<Id>();
        for (Matter_Legal_Hold_Acknowledgement__c a : acks) {
            matterIds.add(a.Matter__c);
        }
        Map<Id, Matter__c> matters = new Map<Id, Matter__c>([SELECT Id, Name, Matter_Number__c FROM Matter__c WHERE Id IN :matterIds]);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Matter_Legal_Hold_Acknowledgement__c a : acks) {
            if (a.Status__c != 'Pending') {
                continue;
            }
            Id target = a.Custodian_Contact__c != null ? a.Custodian_Contact__c : a.Custodian_User__c;
            if (target == null) {
                continue;
            }
            Matter__c m = matters.get(a.Matter__c);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(target);
            mail.setSaveAsActivity(false);
            mail.setSubject('Legal hold notice: ' + m.Matter_Number__c + ' ' + m.Name);
            mail.setPlainTextBody('You have been identified as a custodian of information relevant to matter '
                + m.Matter_Number__c + ' (' + m.Name + ').\n\nPreserve all documents, emails and electronic data that relate to this matter. '
                + 'Do not delete, alter or discard them until you are told in writing that the hold is released.\n\n'
                + 'Please confirm that you have received and understood this notice.');
            mails.add(mail);
        }
        if (mails.isEmpty()) {
            return 0;
        }
        try {
            Messaging.sendEmail(mails, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Legal hold emails not sent: ' + e.getMessage());
        }
        return mails.size();
    }

    /** Calls the class named in Matter Management Settings > Legal Hold Callback Class, if any. */
    public static void notifyCallback(Set<Id> placed, Set<Id> released) {
        String className = MatterManagementSettings.get().Legal_Hold_Callback_Class__c;
        if (String.isBlank(className) || (placed.isEmpty() && released.isEmpty())) {
            return;
        }
        List<Map<String, Object>> recs = new List<Map<String, Object>>();
        for (Id i : placed) {
            recs.add(new Map<String, Object>{ 'recordId' => i, 'status' => 'Added' });
        }
        for (Id i : released) {
            recs.add(new Map<String, Object>{ 'recordId' => i, 'status' => 'Removed' });
        }
        Map<String, Object> payload = new Map<String, Object>{ 'recordsList' => recs, 'success' => true, 'result' => '' };
        Type t = Type.forName(className.trim());
        if (t == null) {
            System.debug(LoggingLevel.WARN, 'Legal hold callback class not found: ' + className);
            return;
        }
        ((LegalHoldCallback) t.newInstance()).handle(JSON.serialize(payload));
    }

    /** Blocks deleting files linked to a matter on legal hold. */
    public static void guardFiles(List<ContentDocument> docs) {
        Map<Id, ContentDocument> byId = new Map<Id, ContentDocument>(docs);
        Map<Id, Set<Id>> mattersByDoc = new Map<Id, Set<Id>>();
        Set<Id> matterIds = new Set<Id>();
        for (ContentDocumentLink l : [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId IN :byId.keySet()]) {
            if (l.LinkedEntityId.getSObjectType() == Matter__c.SObjectType) {
                matterIds.add(l.LinkedEntityId);
                if (!mattersByDoc.containsKey(l.ContentDocumentId)) {
                    mattersByDoc.put(l.ContentDocumentId, new Set<Id>());
                }
                mattersByDoc.get(l.ContentDocumentId).add(l.LinkedEntityId);
            }
        }
        Set<Id> held = LegalHoldGuard.mattersOnHold(matterIds);
        for (Id docId : mattersByDoc.keySet()) {
            for (Id m : mattersByDoc.get(docId)) {
                if (held.contains(m)) {
                    byId.get(docId).addError('This file is attached to a matter on legal hold and cannot be deleted.');
                    break;
                }
            }
        }
    }
}
