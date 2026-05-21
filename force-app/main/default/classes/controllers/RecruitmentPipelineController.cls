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
        @AuraEnabled public Id offerId;
        @AuraEnabled public String offerStatus;
        @AuraEnabled public Boolean offerLetterSent;
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

            Map<Id, Offer__c> latestOfferByApp = new Map<Id, Offer__c>();
            if (!appIds.isEmpty()) {
                for (Offer__c offer : [
                    SELECT Id, Job_Application__c,
                           Offer_Status__c, Offer_Letter_Sent__c
                    FROM Offer__c
                    WHERE Job_Application__c IN :appIds
                    ORDER BY CreatedDate DESC
                ]) {
                    if (!latestOfferByApp.containsKey(
                        offer.Job_Application__c)) {
                        latestOfferByApp.put(
                            offer.Job_Application__c, offer);
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

                Offer__c latestOffer = latestOfferByApp.get(app.Id);
                if (latestOffer != null) {
                    card.offerId = latestOffer.Id;
                    card.offerStatus = latestOffer.Offer_Status__c;
                    card.offerLetterSent =
                        latestOffer.Offer_Letter_Sent__c;
                } else {
                    card.offerId = null;
                    card.offerStatus = null;
                    card.offerLetterSent = false;
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

    @AuraEnabled
    public static Id draftOffer(String appId) {
        try {
            if (String.isBlank(appId)) {
                throw new AuraHandledException('Application Id required.');
            }

            List<Offer__c> existingOffers = [
                SELECT Id, Offer_Status__c, Offer_Letter_Sent__c
                FROM Offer__c
                WHERE Job_Application__c = :appId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!existingOffers.isEmpty()) {
                Offer__c existing = existingOffers[0];
                if (existing.Offer_Letter_Sent__c == true) {
                    throw new AuraHandledException(
                        'Offer already extended.'
                    );
                }
                if (existing.Offer_Status__c != 'Expired') {
                    return existing.Id;
                }
            }

            Job_Application__c app = [
                SELECT Id,
                       Expected_Salary__c,
                       Contact__c,
                       Candidate__c,
                       Job_Opening__r.Job_Title__c,
                       Job_Opening__r.Employment_Type__c,
                       Job_Opening__r.Min_Salary__c,
                       Job_Opening__r.Max_Salary__c,
                       Job_Opening__r.Recruiter__c
                FROM Job_Application__c
                WHERE Id = :appId
                LIMIT 1
            ];

            Decimal offeredSalary = resolveOfferedSalary(app);
            String employmentType = resolveEmploymentType(app);
            String designation = !String.isBlank(
                app.Job_Opening__r != null
                ? app.Job_Opening__r.Job_Title__c
                : null
            ) ? app.Job_Opening__r.Job_Title__c : 'Offer';

            String draftStatus = resolveDraftStatus();
            if (String.isBlank(draftStatus)) {
                throw new AuraHandledException(
                    'No valid offer status available.'
                );
            }

            Offer__c offer = new Offer__c(
                Job_Application__c = app.Id,
                Offer_Status__c = draftStatus,
                Offer_Letter_Sent__c = false,
                Offered_Salary__c = offeredSalary,
                Offer_Date__c = Date.today(),
                Offer_Expiry_Date__c = Date.today().addDays(7),
                Employment_Type__c = employmentType,
                Offered_Designation__c = designation,
                Candidate__c = app.Candidate__c != null
                    ? app.Candidate__c
                    : app.Contact__c,
                Recruiter__c = app.Job_Opening__r != null
                    ? app.Job_Opening__r.Recruiter__c
                    : null
            );
            insert offer;
            return offer.Id;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void extendOffer(String appId) {
        try {
            if (String.isBlank(appId)) {
                throw new AuraHandledException('Application Id required.');
            }

            List<Offer__c> offers = [
                SELECT Id,
                       Offer_Status__c,
                       Offer_Letter_Sent__c,
                       Offer_Date__c,
                       Offer_Expiry_Date__c,
                       Candidate__c,
                       Candidate__r.FirstName,
                       Candidate__r.LastName,
                       Candidate__r.Email,
                       Job_Application__c,
                       Job_Application__r.Contact__c,
                       Job_Application__r.Contact__r.FirstName,
                       Job_Application__r.Contact__r.LastName,
                       Job_Application__r.Contact__r.Email,
                       Job_Application__r.Candidate__c,
                       Job_Application__r.Candidate__r.FirstName,
                       Job_Application__r.Candidate__r.LastName,
                       Job_Application__r.Candidate__r.Email,
                       Job_Application__r.Job_Opening__r.Job_Title__c
                FROM Offer__c
                WHERE Job_Application__c = :appId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (offers.isEmpty()) {
                throw new AuraHandledException(
                    'Draft an offer before extending.'
                );
            }

            Offer__c offer = offers[0];
            if (offer.Offer_Letter_Sent__c == true) {
                throw new AuraHandledException(
                    'Offer already extended.'
                );
            }

            Contact candidate = getCandidateContact(offer);
            if (candidate == null || String.isBlank(candidate.Email)) {
                throw new AuraHandledException(
                    'Candidate email not available.'
                );
            }

            Date expiryDate = offer.Offer_Expiry_Date__c != null
                ? offer.Offer_Expiry_Date__c
                : Date.today().addDays(7);
            Date offerDate = offer.Offer_Date__c != null
                ? offer.Offer_Date__c
                : Date.today();

            String candidateName = getContactName(candidate);
            if (String.isBlank(candidateName)) {
                candidateName = 'there';
            }

            String jobTitle = getJobTitle(offer);

            Messaging.SingleEmailMessage msg =
                new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ candidate.Email });
            msg.setSubject('Offer for ' + jobTitle);
            msg.setPlainTextBody(
                'Hi ' + candidateName + ',\n\n' +
                'We are pleased to extend an offer for ' + jobTitle + '.\n' +
                'Please respond before ' + String.valueOf(expiryDate) + '.\n\n' +
                'Recruitment Team'
            );

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(
                    new List<Messaging.SingleEmailMessage>{ msg },
                    false
                );
            if (results.isEmpty() || !results[0].isSuccess()) {
                throw new AuraHandledException(
                    'Unable to send offer email.'
                );
            }

            offer.Offer_Status__c = 'Sent to Candidate';
            offer.Offer_Letter_Sent__c = true;
            offer.Offer_Date__c = offerDate;
            offer.Offer_Expiry_Date__c = expiryDate;
            update offer;

            update new Job_Application__c(
                Id = appId,
                Application_Stage__c = 'Offer Extended'
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

    private static Decimal resolveOfferedSalary(Job_Application__c app) {
        if (app == null) return null;

        if (app.Expected_Salary__c != null) {
            return app.Expected_Salary__c;
        }

        if (app.Job_Opening__r != null) {
            if (app.Job_Opening__r.Max_Salary__c != null) {
                return app.Job_Opening__r.Max_Salary__c;
            }
            if (app.Job_Opening__r.Min_Salary__c != null) {
                return app.Job_Opening__r.Min_Salary__c;
            }
        }

        throw new AuraHandledException(
            'Set expected salary or job salary range before drafting.'
        );
    }

    private static String resolveEmploymentType(Job_Application__c app) {
        if (app != null
            && app.Job_Opening__r != null
            && !String.isBlank(app.Job_Opening__r.Employment_Type__c)) {
            return app.Job_Opening__r.Employment_Type__c;
        }
        return 'Full-Time';
    }

    private static String resolveDraftStatus() {
        List<Schema.PicklistEntry> values =
            Offer__c.Offer_Status__c.getDescribe().getPicklistValues();
        Set<String> available = new Set<String>();
        for (Schema.PicklistEntry entry : values) {
            available.add(entry.getValue());
        }

        List<String> preferred = new List<String>{
            'Draft',
            'Pending',
            'Created'
        };
        for (String candidate : preferred) {
            if (available.contains(candidate)) {
                return candidate;
            }
        }

        if (available.contains('Sent to Candidate')) {
            return 'Sent to Candidate';
        }

        return values.isEmpty() ? null : values[0].getValue();
    }

    private static Contact getCandidateContact(Offer__c offer) {
        if (offer == null) return null;

        if (offer.Candidate__r != null) {
            return offer.Candidate__r;
        }

        if (offer.Job_Application__r != null) {
            if (offer.Job_Application__r.Contact__r != null) {
                return offer.Job_Application__r.Contact__r;
            }
            if (offer.Job_Application__r.Candidate__r != null) {
                return offer.Job_Application__r.Candidate__r;
            }
        }

        return null;
    }

    private static String getContactName(Contact contact) {
        if (contact == null) return null;
        if (!String.isBlank(contact.FirstName)) {
            return contact.FirstName;
        }
        if (!String.isBlank(contact.LastName)) {
            return contact.LastName;
        }
        return null;
    }

    private static String getJobTitle(Offer__c offer) {
        if (offer != null
            && offer.Job_Application__r != null
            && offer.Job_Application__r.Job_Opening__r != null
            && !String.isBlank(
                offer.Job_Application__r.Job_Opening__r.Job_Title__c
            )) {
            return offer.Job_Application__r.Job_Opening__r.Job_Title__c;
        }

        return 'the role';
    }
}