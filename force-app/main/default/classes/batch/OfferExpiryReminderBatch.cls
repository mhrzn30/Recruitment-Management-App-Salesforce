public with sharing class OfferExpiryReminderBatch
    implements Database.Batchable<SObject>,
               Database.Stateful {

    private Integer totalProcessed = 0;
    private Integer totalReminders = 0;

    public Database.QueryLocator start(
        Database.BatchableContext context
    ) {
        Date targetDate = Date.today().addDays(1);

        return Database.getQueryLocator([
            SELECT Id,
                   Offer_Status__c,
                   Offer_Expiry_Date__c,
                   Job_Application__c,
                   Candidate__c,
                   Candidate__r.FirstName,
                   Candidate__r.LastName,
                   Candidate__r.Email,
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
            AND Offer_Expiry_Date__c = :targetDate
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<Offer__c> scope
    ) {
        totalProcessed += scope.size();

        List<Messaging.SingleEmailMessage> messages =
            new List<Messaging.SingleEmailMessage>();

        for (Offer__c offer : scope) {
            Contact candidate = getCandidateContact(offer);
            if (candidate == null || String.isBlank(candidate.Email)) {
                continue;
            }

            String candidateName = getContactName(candidate);
            if (String.isBlank(candidateName)) {
                candidateName = 'there';
            }

            String jobTitle = getJobTitle(offer);
            String expiryDate = offer.Offer_Expiry_Date__c != null
                ? String.valueOf(offer.Offer_Expiry_Date__c)
                : 'tomorrow';

            Messaging.SingleEmailMessage msg =
                new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ candidate.Email });
            msg.setSubject('Offer expires tomorrow - ' + jobTitle);
            msg.setPlainTextBody(
                'Hi ' + candidateName + ',\n\n' +
                'This is a reminder that your offer for ' + jobTitle +
                ' expires on ' + expiryDate + '.\n' +
                'Please respond before the deadline.\n\n' +
                'Recruitment Team'
            );
            messages.add(msg);
        }

        totalReminders += sendEmailInBatches(messages);
    }

    public void finish(Database.BatchableContext context) {
        System.debug(
            'Offer expiry reminder batch complete. Processed: ' +
            totalProcessed +
            ', Reminders sent: ' +
            totalReminders
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
                System.debug('Candidate email failed: ' + e.getMessage());
            }
        }

        return sent;
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
