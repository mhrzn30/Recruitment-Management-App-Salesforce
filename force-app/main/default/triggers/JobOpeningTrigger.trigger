/**
 * @description Trigger for Job_Opening__c object
 * Handles automation for job opening lifecycle events
 */
trigger JobOpeningTrigger on Job_Opening__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        JobOpeningHandler.notifyRecruiterOnNewJobOpening(Trigger.new);
    }
}