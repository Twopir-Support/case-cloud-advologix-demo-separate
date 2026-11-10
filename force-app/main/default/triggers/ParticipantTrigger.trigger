trigger ParticipantTrigger on Participant__c (before insert, before update, before delete) {
    if (MatterManagementSettings.isDisabled('Disable_Participant_Trigger__c')) {
        return;
    }
    if (Trigger.isDelete) {
        LegalHoldGuard.blockDeletes(Trigger.old, 'Matter__c');
    } else {
        MatterTriggerHandler.assignParticipantRecordTypes(Trigger.new);
    }
}
