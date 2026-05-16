trigger JobApplicationEmailTrigger on Job_Application__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        RecruitmentApplicationEmailHandler.sendOnNewApplications(Trigger.new);
    }
}
