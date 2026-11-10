/** Matter Timeline: everything that happened on a matter, newest first. */
public with sharing class MatterTimelineController {

    public class Item implements Comparable {
        @AuraEnabled public Datetime occurredAt;
        @AuraEnabled public String category;
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String icon;
        public Integer compareTo(Object other) {
            Datetime o = ((Item) other).occurredAt;
            if (occurredAt == o) return 0;
            if (occurredAt == null) return 1;
            if (o == null) return -1;
            return occurredAt > o ? -1 : 1;
        }
    }

    @AuraEnabled
    public static List<Item> getTimeline(Id matterId) {
        List<Item> items = new List<Item>();
        Matter__c m = [SELECT Id, Name, Open_Date__c, Close_Date__c, Statute_of_Limitations__c FROM Matter__c WHERE Id = :matterId];
        if (m.Open_Date__c != null) items.add(item(dt(m.Open_Date__c), 'Key Date', 'Matter opened', null, m.Id, 'standard:case'));
        if (m.Statute_of_Limitations__c != null) items.add(item(dt(m.Statute_of_Limitations__c), 'Key Date', 'Statute of limitations', null, m.Id, 'standard:event'));
        if (m.Close_Date__c != null) items.add(item(dt(m.Close_Date__c), 'Key Date', 'Matter closed', null, m.Id, 'standard:case'));
        for (Task t : [SELECT Id, Subject, ActivityDate, Status, Owner.Name, CreatedDate FROM Task WHERE WhatId = :matterId ORDER BY CreatedDate DESC LIMIT 200]) {
            items.add(item(t.ActivityDate == null ? t.CreatedDate : dt(t.ActivityDate), 'Task', t.Subject, t.Status + ' · ' + t.Owner.Name, t.Id, 'standard:task'));
        }
        for (Event e : [SELECT Id, Subject, StartDateTime, Location FROM Event WHERE WhatId = :matterId ORDER BY StartDateTime DESC LIMIT 200]) {
            items.add(item(e.StartDateTime, 'Event', e.Subject, e.Location, e.Id, 'standard:event'));
        }
        for (Time__c t : [SELECT Id, Entry_Date__c, Time_in_Hours__c, Total_Amount__c, Timekeeper__r.Name, Narrative__c FROM Time__c WHERE Matter__c = :matterId ORDER BY Entry_Date__c DESC LIMIT 200]) {
            items.add(item(dt(t.Entry_Date__c), 'Time', t.Time_in_Hours__c + ' h · ' + t.Timekeeper__r?.Name, t.Narrative__c, t.Id, 'standard:timesheet'));
        }
        for (Expense__c x : [SELECT Id, Expense_Date__c, Amount__c, Category__c, Description__c FROM Expense__c WHERE Matter__c = :matterId ORDER BY Expense_Date__c DESC LIMIT 200]) {
            items.add(item(dt(x.Expense_Date__c), 'Expense', x.Category__c + ' · ' + x.Amount__c, x.Description__c, x.Id, 'standard:expense'));
        }
        for (Invoice__c i : [SELECT Id, Name, Invoice_Date__c, Status__c, Total_Amount__c FROM Invoice__c WHERE Matter__c = :matterId LIMIT 200]) {
            items.add(item(dt(i.Invoice_Date__c), 'Invoice', i.Name + ' · ' + i.Status__c, 'Total ' + i.Total_Amount__c, i.Id, 'standard:partner_fund_claim'));
        }
        for (Offer_and_Demand__c o : [SELECT Id, Type__c, Amount__c, Date__c, Status__c, Party__c FROM Offer_and_Demand__c WHERE Matter__c = :matterId LIMIT 200]) {
            items.add(item(dt(o.Date__c), 'Offer and Demand', o.Type__c + ' · ' + o.Amount__c, o.Status__c + (o.Party__c == null ? '' : ' · ' + o.Party__c), o.Id, 'standard:opportunity'));
        }
        for (Comment__c c : [SELECT Id, Comment__c, Comment_Type__c, CreatedDate, CreatedBy.Name FROM Comment__c WHERE Matter__c = :matterId LIMIT 200]) {
            items.add(item(c.CreatedDate, 'Comment', c.Comment_Type__c + ' comment · ' + c.CreatedBy.Name, c.Comment__c, c.Id, 'standard:feed'));
        }
        for (Participant__c p : [SELECT Id, Participant_Name__c, Role__c, CreatedDate FROM Participant__c WHERE Matter__c = :matterId LIMIT 200]) {
            items.add(item(p.CreatedDate, 'Participant', p.Participant_Name__c + ' added as ' + p.Role__c, null, p.Id, 'standard:contact'));
        }
        for (Matter_Legal_Hold_Acknowledgement__c a : [SELECT Id, Status__c, Notice_Sent__c, Custodian_Contact__r.Name, Custodian_User__r.Name FROM Matter_Legal_Hold_Acknowledgement__c WHERE Matter__c = :matterId LIMIT 200]) {
            String who = a.Custodian_Contact__r?.Name != null ? a.Custodian_Contact__r.Name : a.Custodian_User__r?.Name;
            items.add(item(a.Notice_Sent__c, 'Legal Hold', 'Legal hold notice to ' + who, a.Status__c, a.Id, 'standard:lead_list'));
        }
        items.sort();
        return items;
    }

    private static Datetime dt(Date d) {
        return d == null ? null : Datetime.newInstance(d, Time.newInstance(9, 0, 0, 0));
    }

    private static Item item(Datetime at, String category, String title, String detail, Id recordId, String icon) {
        Item i = new Item();
        i.occurredAt = at; i.category = category; i.title = title; i.detail = detail; i.recordId = recordId; i.icon = icon;
        return i;
    }
}
