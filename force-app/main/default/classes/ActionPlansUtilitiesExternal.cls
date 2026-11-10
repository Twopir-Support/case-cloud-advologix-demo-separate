/**
 * Activity Plans.
 *
 * Public API (same shape as the CaseCloud ActionPlansUtilitiesExternal):
 *   String json = ActionPlansUtilitiesExternal.ApplyActionPlan('My New ActionPlan', templateId, recordIds, 'Matter__c');
 *     recordIds      one Id, or several separated by commas
 *     objectApiName  Matter__c, Account or Contact
 *     returns JSON   {"success": true|false, "result": "<message>"}
 *
 * Each application creates an Activity_Plan__c record and one Task per Activity Plan Template Item,
 * dated from the plan start date (the matter open date for matters) and assigned to the responsible
 * attorney, paralegal or record owner.
 */
public with sharing class ActionPlansUtilitiesExternal {
    public class PlanException extends Exception {}

    public class Request {
        @InvocableVariable(required=true label='Record ID')
        public Id recordId;
        @InvocableVariable(label='Activity Plan Template ID (blank = match matter type)')
        public Id templateId;
    }

    public static String ApplyActionPlan(String newActionPlanName, String templateId, String recordId, String objectApiName) {
        Map<String, Object> out = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();
        try {
            Set<String> allowed = new Set<String>{ 'matter__c', 'account', 'contact' };
            if (objectApiName == null || !allowed.contains(objectApiName.toLowerCase())) {
                throw new PlanException('objectApiName must be Matter__c, Account or Contact.');
            }
            Integer tasks = 0;
            Integer plans = 0;
            for (String rid : recordId.split(',')) {
                if (String.isNotBlank(rid)) {
                    tasks += apply(newActionPlanName, (Id) templateId, (Id) rid.trim());
                    plans++;
                }
            }
            out.put('success', true);
            out.put('result', plans + ' activity plan(s) created with ' + tasks + ' task(s).');
        } catch (Exception e) {
            Database.rollback(sp);
            out.put('success', false);
            out.put('result', e.getMessage());
        }
        return JSON.serialize(out);
    }

    /** "Apply Activity Plan" quick action on Matter: uses the active template for the matter's Type. */
    @AuraEnabled
    public static Integer applyDefaultPlan(Id matterId) {
        try {
            return apply(null, null, matterId);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @InvocableMethod(label='Apply Activity Plan' description='Creates an activity plan and its dated tasks on a matter, account or contact.' category='Matter Management')
    public static List<Integer> applyFromFlow(List<Request> requests) {
        List<Integer> counts = new List<Integer>();
        for (Request r : requests) {
            counts.add(apply(null, r.templateId, r.recordId));
        }
        return counts;
    }

    public static Integer apply(String planName, Id templateId, Id recordId) {
        Schema.SObjectType kind = recordId.getSObjectType();
        Matter__c m;
        Id ownerFallback = UserInfo.getUserId();
        Date base = Date.today();
        if (kind == Matter__c.SObjectType) {
            m = [SELECT Id, Name, Type__c, Open_Date__c, OwnerId, Responsible_Attorney__c, Paralegal__c FROM Matter__c WHERE Id = :recordId];
            if (m.Open_Date__c != null) {
                base = m.Open_Date__c;
            }
            if (m.OwnerId.getSObjectType() == User.SObjectType) {
                ownerFallback = m.OwnerId;
            }
        } else if (kind != Account.SObjectType && kind != Contact.SObjectType) {
            throw new PlanException('Activity plans can be applied to matters, accounts and contacts only.');
        }
        if (templateId == null) {
            if (m == null) {
                throw new PlanException('Choose an activity plan template.');
            }
            List<Activity_Plan_Template__c> templates = [
                SELECT Id FROM Activity_Plan_Template__c
                WHERE Active__c = true AND Type__c = :m.Type__c
                ORDER BY CreatedDate LIMIT 1
            ];
            if (templates.isEmpty()) {
                throw new PlanException('There is no active activity plan template for matter type "' + m.Type__c + '".');
            }
            templateId = templates[0].Id;
        }
        Activity_Plan_Template__c template = [SELECT Id, Name FROM Activity_Plan_Template__c WHERE Id = :templateId];
        List<Activity_Plan_Template_Item__c> items = [
            SELECT Id, Subject__c, Days_Offset__c, Priority__c, Assign_To__c, Description__c, Depends_On__c, Days_After_Dependency__c
            FROM Activity_Plan_Template_Item__c
            WHERE Activity_Plan_Template__c = :templateId
            ORDER BY Step_Order__c NULLS LAST, Name
        ];
        if (items.isEmpty()) {
            throw new PlanException('The selected activity plan template has no items.');
        }

        Activity_Plan__c plan = new Activity_Plan__c(
            Name = (String.isBlank(planName) ? template.Name : planName).left(80),
            Activity_Plan_Template__c = templateId,
            Start_Date__c = base,
            Number_of_Tasks__c = items.size(),
            Matter__c = m == null ? null : m.Id,
            Account__c = kind == Account.SObjectType ? recordId : null,
            Contact__c = kind == Contact.SObjectType ? recordId : null
        );
        insert plan;

        // Due dates: offset from the plan start, or N days after the item this one depends on
        Map<Id, Date> due = new Map<Id, Date>();
        for (Integer pass = 0; pass < items.size(); pass++) {
            for (Activity_Plan_Template_Item__c s : items) {
                if (due.containsKey(s.Id)) {
                    continue;
                }
                if (s.Depends_On__c == null || !new Map<Id, Activity_Plan_Template_Item__c>(items).containsKey(s.Depends_On__c)) {
                    due.put(s.Id, base.addDays(s.Days_Offset__c == null ? 0 : s.Days_Offset__c.intValue()));
                } else if (due.containsKey(s.Depends_On__c)) {
                    due.put(s.Id, due.get(s.Depends_On__c).addDays(s.Days_After_Dependency__c == null ? 0 : s.Days_After_Dependency__c.intValue()));
                }
            }
        }
        List<Task> tasks = new List<Task>();
        for (Activity_Plan_Template_Item__c s : items) {
            Id owner = ownerFallback;
            if (m != null && s.Assign_To__c == 'Responsible Attorney' && m.Responsible_Attorney__c != null) {
                owner = m.Responsible_Attorney__c;
            } else if (m != null && s.Assign_To__c == 'Paralegal' && m.Paralegal__c != null) {
                owner = m.Paralegal__c;
            }
            Task t = new Task(
                OwnerId = owner,
                Subject = (s.Subject__c == null ? 'Activity plan task' : s.Subject__c).left(255),
                ActivityDate = due.containsKey(s.Id) ? due.get(s.Id) : base,
                Activity_Plan_Id__c = plan.Id,
                Activity_Plan_Item_Id__c = s.Id,
                Priority = s.Priority__c == null ? 'Normal' : s.Priority__c,
                Description = s.Description__c
            );
            if (kind == Contact.SObjectType) {
                t.WhoId = recordId;
            } else {
                t.WhatId = recordId;
            }
            tasks.add(t);
        }
        insert tasks;
        return tasks.size();
    }
}
