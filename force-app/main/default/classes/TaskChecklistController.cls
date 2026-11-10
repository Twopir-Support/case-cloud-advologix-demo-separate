/** Task Checklist: a matter's tasks grouped by due date, with one-click completion. */
public with sharing class TaskChecklistController {

    @AuraEnabled
    public static List<Task> getTasks(Id recordId, Boolean includeClosed) {
        if (includeClosed == true) {
            return [SELECT Id, Subject, ActivityDate, Status, Priority, IsClosed, Owner.Name FROM Task WHERE WhatId = :recordId
                    ORDER BY IsClosed, ActivityDate ASC NULLS LAST LIMIT 500];
        }
        return [SELECT Id, Subject, ActivityDate, Status, Priority, IsClosed, Owner.Name FROM Task WHERE WhatId = :recordId AND IsClosed = false
                ORDER BY ActivityDate ASC NULLS LAST LIMIT 500];
    }

    @AuraEnabled
    public static void completeTask(Id taskId) {
        List<TaskStatus> closed = [SELECT ApiName FROM TaskStatus WHERE IsClosed = true ORDER BY SortOrder LIMIT 1];
        update new Task(Id = taskId, Status = closed.isEmpty() ? 'Completed' : closed[0].ApiName);
    }
}
