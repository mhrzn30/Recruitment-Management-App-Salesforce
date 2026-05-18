public with sharing class RecruitmentPipelineController {

    public class ApplicationCard {
        @AuraEnabled public Id Id;
        @AuraEnabled public String applicationStage;
        @AuraEnabled public Date appliedDate;
        @AuraEnabled public Decimal expectedSalary;
        @AuraEnabled public Integer daysInCurrentStage;
        @AuraEnabled public String candidateFirstName;
        @AuraEnabled public String candidateLastName;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String accountName;
        @AuraEnabled public String latestInterviewRound;
        @AuraEnabled public Id pendingTaskId;
        @AuraEnabled public String pendingTaskSubject;
        @AuraEnabled public Date pendingTaskDueDate;
        @AuraEnabled public String pendingTaskPriority;
        @AuraEnabled public Boolean isTaskOverdue;
    }

    @AuraEnabled(cacheable=true)
    public static List<ApplicationCard> getApplications() {
        try {
            List<Job_Application__c> apps = [
                SELECT Id,
                       Application_Stage__c,
                       Applied_Date__c,
                       Expected_Salary__c,
                       Days_in_Current_Stage__c,
                       Contact__r.FirstName,
                       Contact__r.LastName,
                       Job_Opening__r.Job_Title__c,
                       Job_Opening__r.Account__r.Name
                FROM Job_Application__c
                WHERE Application_Stage__c NOT IN (
                    'Rejected', 'Withdrawn', 'On Hold'
                )
                ORDER BY Applied_Date__c DESC
                LIMIT 100
            ];

            Set<Id> appIds = new Set<Id>();
            for (Job_Application__c app : apps) {
                appIds.add(app.Id);
            }

            Map<Id, Interview__c> latestInterviewByApp =
                new Map<Id, Interview__c>();
            if (!appIds.isEmpty()) {
                for (Interview__c interview : [
                    SELECT Id, Job_Application__c, Interview_Round__c,
                           Interview_DateTime__c, CreatedDate
                    FROM Interview__c
                    WHERE Job_Application__c IN :appIds
                    ORDER BY Interview_DateTime__c DESC NULLS LAST,
                             CreatedDate DESC
                ]) {
                    if (!latestInterviewByApp.containsKey(
                        interview.Job_Application__c)) {
                        latestInterviewByApp.put(
                            interview.Job_Application__c, interview);
                    }
                }
            }

            Map<Id, Task> pendingTaskMap = new Map<Id, Task>();
            if (!appIds.isEmpty()) {
                for (Task t : [
                    SELECT Id, Subject, ActivityDate, Priority, WhatId
                    FROM Task
                    WHERE WhatId IN :appIds
                    AND Status != 'Completed'
                    AND IsClosed = false
                    ORDER BY ActivityDate ASC
                ]) {
                    if (!pendingTaskMap.containsKey(t.WhatId)) {
                        pendingTaskMap.put(t.WhatId, t);
                    }
                }
            }

            List<ApplicationCard> cards = new List<ApplicationCard>();
            for (Job_Application__c app : apps) {
                ApplicationCard card = new ApplicationCard();
                card.Id = app.Id;
                card.applicationStage = app.Application_Stage__c;
                card.appliedDate = app.Applied_Date__c;
                card.expectedSalary = app.Expected_Salary__c;
                card.daysInCurrentStage =
                    app.Days_in_Current_Stage__c != null
                    ? Integer.valueOf(app.Days_in_Current_Stage__c)
                    : null;
                card.candidateFirstName =
                    app.Contact__r != null
                    ? app.Contact__r.FirstName
                    : null;
                card.candidateLastName =
                    app.Contact__r != null
                    ? app.Contact__r.LastName
                    : null;
                card.jobTitle = app.Job_Opening__r != null
                    ? app.Job_Opening__r.Job_Title__c
                    : null;
                card.accountName =
                    (app.Job_Opening__r != null
                    && app.Job_Opening__r.Account__r != null)
                    ? app.Job_Opening__r.Account__r.Name
                    : null;

                Interview__c latestInterview =
                    latestInterviewByApp.get(app.Id);
                card.latestInterviewRound =
                    latestInterview != null
                    ? latestInterview.Interview_Round__c
                    : null;

                Task pendingTask = pendingTaskMap.get(app.Id);
                if (pendingTask != null) {
                    card.pendingTaskId = pendingTask.Id;
                    card.pendingTaskSubject = pendingTask.Subject;
                    card.pendingTaskDueDate = pendingTask.ActivityDate;
                    card.pendingTaskPriority = pendingTask.Priority;
                    card.isTaskOverdue =
                        pendingTask.ActivityDate != null
                        && pendingTask.ActivityDate < Date.today();
                } else {
                    card.pendingTaskId = null;
                    card.pendingTaskSubject = null;
                    card.pendingTaskDueDate = null;
                    card.pendingTaskPriority = null;
                    card.isTaskOverdue = false;
                }

                cards.add(card);
            }

            return cards;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateStage(String recordId, String newStage) {
        try {
            Job_Application__c app = new Job_Application__c(
                Id = recordId,
                Application_Stage__c = newStage
            );
            update app;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void completeTask(String taskId) {
        try {
            update new Task(
                Id = taskId,
                Status = 'Completed'
            );
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Id getLatestInterview(String appId) {
        try {
            List<Interview__c> interviews = [
                SELECT Id
                FROM Interview__c
                WHERE Job_Application__c = :appId
                AND Status__c != 'Completed'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return interviews.isEmpty() ? null : interviews[0].Id;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}