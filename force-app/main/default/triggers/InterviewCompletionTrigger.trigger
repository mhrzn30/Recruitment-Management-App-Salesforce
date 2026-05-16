trigger InterviewCompletionTrigger on Interview__c (after update) {
    InterviewCompletionHandler.handle(Trigger.new, Trigger.oldMap);
}
