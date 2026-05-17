public with sharing class CloseExpiredOffersBatch
    implements Database.Batchable<SObject>,
               Database.Stateful {

    private Integer totalProcessed = 0;
    private Integer totalExpired = 0;
    private Integer totalApplicationsOnHold = 0;
    private Integer totalRecruiterNotified = 0;

    public Database.QueryLocator start(
        Database.BatchableContext context
    ) {
        return Database.getQueryLocator([
            SELECT Id,
                   Offer_Status__c,
                   Offer_Expiry_Date__c,
                   Job_Application__c,
                   Candidate__c,
                   Candidate__r.FirstName,
                   Candidate__r.LastName,
                   Recruiter__c,
                   Recruiter__r.Name,
                   Recruiter__r.Email,
                   Job_Application__r.Application_Stage__c,
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
            WHERE Offer_Status__c = 'Sent to Candidate'
            AND Offer_Expiry_Date__c < TODAY
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<Offer__c> scope
    ) {
        totalProcessed += scope.size();

        List<Offer__c> offersToExpire = new List<Offer__c>();
        Map<Id, Job_Application__c> appsToHold =
            new Map<Id, Job_Application__c>();
        List<Messaging.SingleEmailMessage> recruiterMessages =
            new List<Messaging.SingleEmailMessage>();

        for (Offer__c offer : scope) {
            offersToExpire.add(new Offer__c(
                Id = offer.Id,
                Offer_Status__c = 'Expired'
            ));

            if (offer.Job_Application__c != null
                && offer.Job_Application__r != null
                && offer.Job_Application__r.Application_Stage__c
                    != 'On Hold') {
                appsToHold.put(
                    offer.Job_Application__c,
                    new Job_Application__c(
                        Id = offer.Job_Application__c,
                        Application_Stage__c = 'On Hold'
                    )
                );
            }

            String recruiterEmail = getRecruiterEmail(offer);
            if (!String.isBlank(recruiterEmail)) {
                String recruiterName = getRecruiterName(offer);
                String candidateName = getCandidateName(offer);
                String jobTitle = getJobTitle(offer);
                String expiryDate = offer.Offer_Expiry_Date__c != null
                    ? String.valueOf(offer.Offer_Expiry_Date__c)
                    : 'today';

                Messaging.SingleEmailMessage msg =
                    new Messaging.SingleEmailMessage();
                msg.setToAddresses(new List<String>{ recruiterEmail });
                msg.setSubject('Offer expired - ' + jobTitle);
                msg.setPlainTextBody(
                    'Hi ' + recruiterName + ',\n\n' +
                    'The offer for ' + candidateName + ' (' + jobTitle + ') ' +
                    'expired on ' + expiryDate + '.\n' +
                    'The related application has been moved to On Hold.\n\n' +
                    'Recruitment Team'
                );
                recruiterMessages.add(msg);
            }
        }

        if (!offersToExpire.isEmpty()) {
            Database.SaveResult[] offerResults =
                Database.update(offersToExpire, false);
            for (Database.SaveResult sr : offerResults) {
                if (sr.isSuccess()) {
                    totalExpired++;
                }
            }
        }

        if (!appsToHold.isEmpty()) {
            Database.SaveResult[] appResults =
                Database.update(appsToHold.values(), false);
            for (Database.SaveResult sr : appResults) {
                if (sr.isSuccess()) {
                    totalApplicationsOnHold++;
                }
            }
        }

        totalRecruiterNotified += sendEmailInBatches(
            recruiterMessages
        );
    }

    public void finish(Database.BatchableContext context) {
        System.debug(
            'Expired offers batch complete. Processed: ' +
            totalProcessed +
            ', Expired: ' +
            totalExpired +
            ', Applications On Hold: ' +
            totalApplicationsOnHold +
            ', Recruiter notifications: ' +
            totalRecruiterNotified
        );
    }

    private static Integer sendEmailInBatches(
        List<Messaging.SingleEmailMessage> messages
    ) {
        if (messages == null || messages.isEmpty()) return 0;

        Integer sent = 0;
        Integer batchSize = 10;
        for (Integer i = 0; i < messages.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, messages.size());
            List<Messaging.SingleEmailMessage> batch =
                new List<Messaging.SingleEmailMessage>();
            for (Integer j = i; j < endIndex; j++) {
                batch.add(messages[j]);
            }

            try {
                Messaging.sendEmail(batch, false);
                sent += batch.size();
            } catch (Exception e) {
                System.debug('Recruiter email failed: ' + e.getMessage());
            }
        }

        return sent;
    }

    private static String getRecruiterEmail(Offer__c offer) {
        if (offer != null && offer.Recruiter__r != null
            && !String.isBlank(offer.Recruiter__r.Email)) {
            return offer.Recruiter__r.Email;
        }
        return null;
    }

    private static String getRecruiterName(Offer__c offer) {
        if (offer != null && offer.Recruiter__r != null
            && !String.isBlank(offer.Recruiter__r.Name)) {
            return offer.Recruiter__r.Name;
        }
        return 'there';
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

    private static String getCandidateName(Offer__c offer) {
        String name = getContactName(getCandidateContact(offer));
        return String.isBlank(name) ? 'the candidate' : name;
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
