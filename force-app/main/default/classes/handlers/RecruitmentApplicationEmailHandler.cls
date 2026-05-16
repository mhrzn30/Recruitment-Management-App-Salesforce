public with sharing class RecruitmentApplicationEmailHandler {
    public static void sendOnNewApplications(List<Job_Application__c> newApps) {
        if (newApps == null || newApps.isEmpty()) return;

        Set<Id> contactIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();

        for (Job_Application__c app : newApps) {
            if (app == null) continue;
            if (app.Contact__c != null) contactIds.add(app.Contact__c);
            if (app.Candidate__c != null) contactIds.add(app.Candidate__c);
            if (app.Job_Opening__c != null) jobIds.add(app.Job_Opening__c);
        }

        if (contactIds.isEmpty()) return;

        Map<Id, Contact> contacts = new Map<Id, Contact>([
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Id IN :contactIds
        ]);

        Map<Id, Job_Opening__c> jobs = new Map<Id, Job_Opening__c>();
        if (!jobIds.isEmpty()) {
            jobs = new Map<Id, Job_Opening__c>([
                SELECT Id, Name, Job_Title__c
                FROM Job_Opening__c
                WHERE Id IN :jobIds
            ]);
        }

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Job_Application__c app : newApps) {
            Id contactId = app.Contact__c != null ? app.Contact__c : app.Candidate__c;
            if (contactId == null) continue;

            Contact contact = contacts.get(contactId);
            if (contact == null || String.isBlank(contact.Email)) continue;

            Job_Opening__c job = app.Job_Opening__c != null
                ? jobs.get(app.Job_Opening__c)
                : null;
            String jobTitle = 'the role';
            if (job != null) {
                jobTitle = !String.isBlank(job.Job_Title__c)
                    ? job.Job_Title__c
                    : job.Name;
            }

            String recipientName = !String.isBlank(contact.FirstName)
                ? contact.FirstName
                : contact.LastName;

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setToAddresses(new String[] { contact.Email });
            message.setSubject('Application received');
            message.setPlainTextBody(
                'Hi ' + recipientName + ',\n\n'
                + 'Thanks for applying for ' + jobTitle + '. '
                + 'We have received your application and will review it shortly.\n\n'
                + 'Best regards,\n'
                + 'Recruitment Team'
            );
            messages.add(message);
        }

        if (messages.isEmpty()) return;

        Integer batchSize = 10;
        for (Integer i = 0; i < messages.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, messages.size());
            List<Messaging.SingleEmailMessage> batch = new List<Messaging.SingleEmailMessage>();
            for (Integer j = i; j < endIndex; j++) {
                batch.add(messages[j]);
            }
            Messaging.sendEmail(batch);
        }
    }
}
