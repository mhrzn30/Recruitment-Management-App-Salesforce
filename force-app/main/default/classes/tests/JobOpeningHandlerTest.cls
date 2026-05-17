@isTest
private class JobOpeningHandlerTest {
    @isTest
    static void testNotifyRecruiterOnNewJobOpening() {
        // Create test user to be owner
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        // Create test account with required fields
        Account acct = new Account(Name = 'Handler Test Co', Phone = '555-0200');
        insert acct;
        
        // Insert job opening as that user
        System.runAs(u) {
            Job_Opening__c job = new Job_Opening__c(
                Job_Title__c = 'Automation Test Role',
                Status__c = 'Open',
                Openings_Count__c = 1,
                Account__c = acct.Id,
                Employment_Type__c = 'Full-Time',
                Department__c = 'Engineering'
            );
            insert job;
        }
        
        // Query for the created task
        List<Task> tasks = [SELECT Id, Subject, OwnerId, WhatId FROM Task WHERE WhatId IN (SELECT Id FROM Job_Opening__c WHERE Job_Title__c = 'Automation Test Role')];
        System.assertEquals(1, tasks.size(), 'A single task should be created for the new job opening');
        System.assert(tasks[0].Subject.contains('New Job Opening Created'), 'Task subject should reference new job opening');
    }
}