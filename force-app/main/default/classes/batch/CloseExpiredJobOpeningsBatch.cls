public with sharing class CloseExpiredJobOpeningsBatch
    implements Database.Batchable<SObject>,
               Database.Stateful {

    private Integer totalProcessed = 0;
    private Integer totalClosed = 0;

    public Database.QueryLocator start(
        Database.BatchableContext context
    ) {
        return Database.getQueryLocator([
            SELECT Id,
                   Job_Title__c,
                   Status__c,
                   Application_Deadline__c,
                   Account__r.Name
            FROM Job_Opening__c
            WHERE Status__c = 'Open'
            AND Application_Deadline__c < TODAY
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<Job_Opening__c> scope
    ) {
        totalProcessed += scope.size();

        List<Job_Opening__c> toClose = new List<Job_Opening__c>();
        for (Job_Opening__c jo : scope) {
            toClose.add(new Job_Opening__c(
                Id = jo.Id,
                Status__c = 'Closed'
            ));
        }

        Database.SaveResult[] results =
            Database.update(toClose, false);

        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                totalClosed++;
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        String summary =
            'Expired Job Openings Batch Complete\n\n' +
            'Total Processed : ' + totalProcessed + '\n' +
            'Total Closed    : ' + totalClosed + '\n' +
            'Run Date        : ' + Date.today() + '\n\n' +
            'Note: Existing applications remain in their' +
            ' current stages. New applications are blocked' +
            ' by validation rules.';

        Messaging.SingleEmailMessage email =
            new Messaging.SingleEmailMessage();
        email.setToAddresses(
            new List<String>{ UserInfo.getUserEmail() }
        );
        email.setSubject(
            'Batch Complete - Expired Job Openings Closed'
        );
        email.setPlainTextBody(summary);

        try {
            Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ email }
            );
        } catch (Exception e) {
            System.debug('Email failed: ' + e.getMessage());
        }

        System.debug(summary);
    }
}
