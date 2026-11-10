/**
 * Conflict Check.
 *
 * Public API (same shape as the CaseCloud ConflictSearchService):
 *   ConflictSearchService.InputWrapper input = new ConflictSearchService.InputWrapper();
 *   input.searchTerm = '(John OR Jane) AND Smith';      // required; OR / AND / quotes not supported, commas split terms
 *   input.description = 'John Smith Account Check';     // optional
 *   input.matterId = matterId;                          // optional
 *   input.contextRecordId = intakeId;                   // optional, any record; an Intake id links the check to it
 *   List<ConflictSearchService.ResultWrapper> results = ConflictSearchService.executeSearch(new List<ConflictSearchService.InputWrapper>{ input });
 *   results[0].status  -> 'TRUE' (success) or 'FALSE'
 *   results[0].body    -> status message
 *
 * Matching: each term is compared with Account names, Contact names and free-text Participant names.
 * Every matter role held by a match becomes a Conflict Check Result. A prospective client who is already
 * a client on another matter is resolved automatically as "Not a Conflict"; all other results need review.
 */
public with sharing class ConflictSearchService {
    public class ConflictException extends Exception {}

    public class InputWrapper {
        @InvocableVariable(required=true label='Search Term')
        @AuraEnabled public String searchTerm;
        @InvocableVariable(label='Description')
        @AuraEnabled public String description;
        @InvocableVariable(label='Matter ID')
        @AuraEnabled public Id matterId;
        @InvocableVariable(label='Context Record ID')
        @AuraEnabled public Id contextRecordId;
    }

    public class ResultWrapper {
        @InvocableVariable @AuraEnabled public String body;
        @InvocableVariable @AuraEnabled public String status;
        @InvocableVariable @AuraEnabled public Id conflictCheckId;
        @InvocableVariable @AuraEnabled public String conflictStatus;
        @InvocableVariable @AuraEnabled public Integer results;
    }

    private static final String CLIENT_TERM = 'client';
    private static final String OTHER_TERM = 'other';

    @InvocableMethod(label='Initiate Conflict Check' description='Searches existing parties for the search term and records conflict check results.' category='Matter Management')
    public static List<ResultWrapper> executeSearch(List<InputWrapper> inputs) {
        List<ResultWrapper> out = new List<ResultWrapper>();
        for (InputWrapper input : inputs) {
            ResultWrapper r;
            try {
                Map<String, String> terms = new Map<String, String>();
                if (input.searchTerm != null) {
                    String cleaned = input.searchTerm.replaceAll('[()"]', ' ').replaceAll('(?i)\\s+(AND|OR)\\s+', ',');
                    for (String t : cleaned.split(',')) {
                        addTerm(terms, t, OTHER_TERM);
                    }
                }
                if (terms.isEmpty()) {
                    throw new ConflictException('Enter a search term of at least 3 characters.');
                }
                Id intakeId = input.contextRecordId != null
                    && input.contextRecordId.getSObjectType() == Intake__c.SObjectType ? input.contextRecordId : null;
                r = run(terms, intakeId, input.matterId, input.description);
            } catch (Exception e) {
                r = new ResultWrapper();
                r.status = 'FALSE';
                r.body = e.getMessage();
            }
            out.add(r);
        }
        return out;
    }

    /** Batch Conflict Check page: runs up to 20 searches. */
    @AuraEnabled
    public static List<ResultWrapper> runBatch(List<InputWrapper> inputs) {
        if (inputs != null && inputs.size() > 20) {
            AuraHandledException ex = new AuraHandledException('Enter 20 names or fewer per batch.');
            ex.setMessage('Enter 20 names or fewer per batch.');
            throw ex;
        }
        return executeSearch(inputs);
    }

    /** "Conflict Check" quick action on Intake: searches the intake name, account, contact and adverse party. */
    @AuraEnabled
    public static ResultWrapper runForIntake(Id intakeId) {
        try {
            return checkIntake(intakeId);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    public static ResultWrapper checkIntake(Id intakeId) {
        Intake__c i = [
            SELECT Id, Name, Status__c, Adverse_Party__c, Primary_Account__r.Name, Primary_Contact__r.Name
            FROM Intake__c WHERE Id = :intakeId
        ];
        Map<String, String> terms = new Map<String, String>();
        addTerm(terms, i.Name, CLIENT_TERM);
        addTerm(terms, i.Primary_Account__r?.Name, CLIENT_TERM);
        addTerm(terms, i.Primary_Contact__r?.Name, CLIENT_TERM);
        addTerm(terms, i.Adverse_Party__c, OTHER_TERM);
        if (terms.isEmpty()) {
            throw new ConflictException('Add an intake name, account, contact or adverse party before running a conflict check.');
        }
        ResultWrapper r = run(terms, intakeId, null, 'Intake conflict check: ' + i.Name);
        Intake__c upd = new Intake__c(Id = intakeId, Conflict_Status__c = r.conflictStatus);
        if (i.Status__c == 'Requested') {
            upd.Status__c = 'In Progress';
        }
        update upd;
        return r;
    }

    private static void addTerm(Map<String, String> terms, String term, String kind) {
        if (String.isBlank(term)) {
            return;
        }
        String clean = term.trim();
        if (clean.length() < 3) {
            return;
        }
        String key = clean.toLowerCase();
        if (!terms.containsKey(key) || kind == CLIENT_TERM) {
            terms.put(key, kind);
        }
    }

    private static ResultWrapper run(Map<String, String> terms, Id intakeId, Id matterId, String description) {
        Map<Id, String> accountTerm = new Map<Id, String>();
        Map<Id, String> contactTerm = new Map<Id, String>();
        Map<Id, String> participantTerm = new Map<Id, String>();
        Map<Id, String> matchedName = new Map<Id, String>();
        for (String term : terms.keySet()) {
            String pattern = '%' + term + '%';
            for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE :pattern LIMIT 50]) {
                accountTerm.put(a.Id, term);
                matchedName.put(a.Id, a.Name);
            }
            for (Contact c : [SELECT Id, Name FROM Contact WHERE Name LIKE :pattern LIMIT 50]) {
                contactTerm.put(c.Id, term);
                matchedName.put(c.Id, c.Name);
            }
            for (Participant__c p : [SELECT Id, Other_Name__c FROM Participant__c WHERE Other_Name__c LIKE :pattern LIMIT 50]) {
                participantTerm.put(p.Id, term);
                matchedName.put(p.Id, p.Other_Name__c);
            }
        }

        Conflict_Check__c check = new Conflict_Check__c(
            Intake__c = intakeId,
            Matter__c = matterId,
            Search_Term__c = String.join(new List<String>(terms.keySet()), ', ').left(255),
            Description__c = description,
            Run_Date__c = System.now(),
            Status__c = 'Pending'
        );
        insert check;

        List<Conflict_Check_Result__c> results = new List<Conflict_Check_Result__c>();
        Boolean needsReview = false;
        for (Participant__c p : [
            SELECT Id, Role__c, Account__c, Contact__c, Matter__c, Matter__r.Name, Matter__r.Matter_Number__c
            FROM Participant__c
            WHERE (Account__c IN :accountTerm.keySet() OR Contact__c IN :contactTerm.keySet() OR Id IN :participantTerm.keySet())
            LIMIT 500
        ]) {
            if (matterId != null && p.Matter__c == matterId) {
                continue;
            }
            Id matchedId;
            String term;
            String objectLabel;
            if (p.Account__c != null && accountTerm.containsKey(p.Account__c)) {
                matchedId = p.Account__c; term = accountTerm.get(p.Account__c); objectLabel = 'Account';
            } else if (p.Contact__c != null && contactTerm.containsKey(p.Contact__c)) {
                matchedId = p.Contact__c; term = contactTerm.get(p.Contact__c); objectLabel = 'Contact';
            } else {
                matchedId = p.Id; term = participantTerm.get(p.Id); objectLabel = 'Participant';
            }
            Boolean sameSide = terms.get(term) == CLIENT_TERM && p.Role__c == 'Client';
            if (!sameSide) {
                needsReview = true;
            }
            results.add(new Conflict_Check_Result__c(
                Conflict_Check__c = check.Id,
                Matched_Term__c = term.left(255),
                Matched_Name__c = String.valueOf(matchedName.get(matchedId)).left(255),
                Matched_Object__c = objectLabel,
                Matched_Record_Id__c = matchedId,
                Context__c = (p.Role__c + ' on ' + p.Matter__r.Matter_Number__c + ' (' + p.Matter__r.Name + ')').left(255),
                Resolution__c = sameSide ? 'Not a Conflict' : 'Unreviewed'
            ));
        }
        insert results;
        check.Status__c = needsReview ? 'Potential Conflict' : 'Clear';
        update check;

        ResultWrapper r = new ResultWrapper();
        r.status = 'TRUE';
        r.conflictCheckId = check.Id;
        r.conflictStatus = check.Status__c;
        r.results = results.size();
        r.body = 'Conflict check completed: ' + check.Status__c + ' (' + results.size() + ' result(s)).';
        return r;
    }
}
