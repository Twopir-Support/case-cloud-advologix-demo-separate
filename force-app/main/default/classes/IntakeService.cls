/**
 * Convert to Matter: creates a Matter from an approved, conflict-cleared Intake, links the Intake
 * to the new Matter and re-points the Intake's Conflict Checks to it.
 * Callable from the "Convert to Matter" quick action and from Flow.
 */
public with sharing class IntakeService {
    public class IntakeException extends Exception {}

    private static final Map<String, Schema.RecordTypeInfo> MATTER_RTS =
        Matter__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

    @AuraEnabled
    public static Id convertIntake(Id intakeId) {
        try {
            return convert(new List<Id>{ intakeId })[0];
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @InvocableMethod(label='Convert to Matter'
        description='Creates a matter from each approved intake whose conflict check is clear or waived.'
        category='Matter Management')
    public static List<Id> convertFromFlow(List<Id> intakeIds) {
        return convert(intakeIds);
    }

    public static List<Id> convert(List<Id> intakeIds) {
        List<Intake__c> intakes = [
            SELECT Id, Name, Status__c, Conflict_Status__c, Type__c,
                   Primary_Account__c, Primary_Contact__c, Approver__c, OwnerId, Description__c, Matter_Record_Type__c,
                   Adverse_Party__c, Matter__c
            FROM Intake__c
            WHERE Id IN :intakeIds
        ];
        Map<Id, Matter__c> matterByIntake = new Map<Id, Matter__c>();
        for (Intake__c i : intakes) {
            if (i.Matter__c != null) {
                throw new IntakeException(i.Name + ' has already been converted to a matter.');
            }
            if (i.Status__c != 'Approved') {
                throw new IntakeException('Only approved intakes can be converted. ' + i.Name + ' is ' + i.Status__c + '.');
            }
            if (i.Conflict_Status__c != 'Clear' && i.Conflict_Status__c != 'Waived') {
                throw new IntakeException('Run a conflict check on ' + i.Name + ' and clear or waive it before converting.');
            }
            String matterName = i.Name;
            Id attorney = i.Approver__c;
            if (attorney == null && i.OwnerId.getSObjectType() == User.SObjectType) {
                attorney = i.OwnerId;
            }
            Matter__c newMatter = new Matter__c(
                Name = matterName.left(80),
                Type__c = i.Type__c,
                Primary_Account__c = i.Primary_Account__c,
                Primary_Contact__c = i.Primary_Contact__c,
                Responsible_Attorney__c = attorney,
                Status__c = 'Open',
                Stage__c = 'Investigation',
                Open_Date__c = Date.today(),
                Description__c = i.Description__c
            );
            if (String.isNotBlank(i.Matter_Record_Type__c)) {
                Schema.RecordTypeInfo rt = MATTER_RTS.get(i.Matter_Record_Type__c);
                if (rt == null || !rt.isActive()) {
                    throw new IntakeException('Matter Record Type "' + i.Matter_Record_Type__c + '" on ' + i.Name
                        + ' does not match an active Matter record type developer name.');
                }
                newMatter.RecordTypeId = rt.getRecordTypeId();
            }
            matterByIntake.put(i.Id, newMatter);
        }
        insert matterByIntake.values();

        List<Participant__c> adverse = new List<Participant__c>();
        for (Intake__c i : intakes) {
            Matter__c m = matterByIntake.get(i.Id);
            if (String.isNotBlank(i.Adverse_Party__c)) {
                adverse.add(new Participant__c(Matter__c = m.Id, Role__c = 'Opposing Party', Other_Name__c = i.Adverse_Party__c));
            }
            i.Matter__c = m.Id;
        }
        insert adverse;
        update intakes;

        List<Conflict_Check__c> checks = [
            SELECT Id, Intake__c FROM Conflict_Check__c WHERE Intake__c IN :matterByIntake.keySet()
        ];
        for (Conflict_Check__c c : checks) {
            c.Matter__c = matterByIntake.get(c.Intake__c).Id;
        }
        update checks;

        List<Id> result = new List<Id>();
        for (Id intakeId : intakeIds) {
            Matter__c m = matterByIntake.get(intakeId);
            result.add(m == null ? null : m.Id);
        }
        return result;
    }
}
