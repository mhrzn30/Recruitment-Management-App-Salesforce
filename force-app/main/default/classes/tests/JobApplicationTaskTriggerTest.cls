@isTest
private class JobApplicationTaskTriggerTest {

    @testSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Test Corp',
            Account_Status__c = 'Active',
            Primary_Industry_Sector__c = 'Information Technology',
            Phone = '415-555-0101',
            Website = 'https://example.com'
        );
        insert acc;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            Contact_Type__c = 'Candidate',
            Candidate_Status__c = 'Active — Looking',
            Email = 'test@test.com'
        );
        insert c;

        Job_Opening__c jo = new Job_Opening__c(
            Job_Title__c = 'Senior Developer',
            Account__c = acc.Id,
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering',
            Openings_Count__c = 1,
            Application_Deadline__c = Date.today().addDays(30)
        );
        insert jo;
    }

    // ── helpers ──────────────────────────────────────────────

    private static Contact getContact() {
        return [SELECT Id FROM Contact LIMIT 1];
    }

    private static Job_Opening__c getJobOpening() {
        return [SELECT Id FROM Job_Opening__c LIMIT 1];
    }

    private static String getRejectionReason() {
        return 'Underqualified';
    }

    private static Job_Application__c insertApp(String stage) {
        Job_Application__c app = new Job_Application__c(
            Contact__c = getContact().Id,
            Job_Opening__c = getJobOpening().Id,
            Application_Stage__c = stage,
            Applied_Date__c = Date.today()
        );
        insert app;
        return app;
    }

    private static List<Task> getTasksForApp(Id appId) {
        return [
            SELECT Id, Subject, Status, Priority
            FROM Task
            WHERE WhatId = :appId
        ];
    }

    // ── INSERT Tests ──────────────────────────────────────────

    @isTest
    static void test_newApplication_createsScreeningTask() {
        Test.startTest();
        Job_Application__c app = insertApp('New');
        Test.stopTest();

        List<Task> tasks = getTasksForApp(app.Id);

        Assert.isTrue(tasks.size() >= 1,
            'Screening task should be created');

        Boolean hasScreenTask = false;
        for(Task t : tasks) {
            if(t.Subject.containsIgnoreCase('Screen')) {
                hasScreenTask = true;
                Assert.areEqual('High', t.Priority,
                    'Screening task should be High priority');
                Assert.areEqual('Not Started', t.Status,
                    'Task should be Not Started');
            }
        }
        Assert.isTrue(hasScreenTask,
            'Screen & Shortlist task should exist');
    }

    @isTest
    static void test_bulkInsert_createsTasksForAll() {
        Contact c = getContact();
        Job_Opening__c jo = getJobOpening();

        List<Job_Application__c> apps =
            new List<Job_Application__c>();
        for(Integer i = 0; i < 50; i++) {
            apps.add(new Job_Application__c(
                Contact__c = c.Id,
                Job_Opening__c = jo.Id,
                Application_Stage__c = 'New',
                Applied_Date__c = Date.today()
            ));
        }

        Test.startTest();
        insert apps;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :apps
        ];
        Assert.areEqual(50, tasks.size(),
            'One task per application should be created');
    }

    // ── UPDATE Tests ──────────────────────────────────────────

    @isTest
    static void test_shortlisted_closesScreeningTask() {
        Job_Application__c app = insertApp('New');

        // verify screening task exists
        List<Task> screenTasks = [
            SELECT Id, Status FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Screen%'
        ];
        Assert.isTrue(screenTasks.size() >= 1,
            'Screening task should exist before shortlist');

        Test.startTest();
        app.Application_Stage__c = 'Shortlisted';
        update app;
        Test.stopTest();

        // screening task should be closed
        Task closedTask = [
            SELECT Status FROM Task
            WHERE Id = :screenTasks[0].Id
        ];
        Assert.areEqual('Completed', closedTask.Status,
            'Screening task should be closed on Shortlist');
    }

    @isTest
    static void test_shortlisted_createsInterviewTask() {
        Job_Application__c app = insertApp('New');

        Test.startTest();
        app.Application_Stage__c = 'Shortlisted';
        update app;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Schedule Interview%'
        ];
        Assert.isTrue(tasks.size() >= 1,
            'Schedule Interview task should be created');
    }

    @isTest
    static void test_offerPending_createsPrepareOfferTask() {
        Job_Application__c app = insertApp('Interview Scheduled');

        Test.startTest();
        app.Application_Stage__c = 'Offer Pending';
        update app;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Prepare Offer%'
        ];
        Assert.isTrue(tasks.size() >= 1,
            'Prepare Offer task should be created');
    }

    @isTest
    static void test_hired_createsInvoiceTask() {
        Job_Application__c app = insertApp('Offer Extended');

        Test.startTest();
        app.Application_Stage__c = 'Hired';
        update app;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, Priority FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Invoice%'
        ];
        Assert.isTrue(tasks.size() >= 1,
            'Invoice task should be created on hire');
        Assert.areEqual('High', tasks[0].Priority,
            'Invoice task should be High priority');
    }

    @isTest
    static void test_rejected_createsNotifyTask() {
        Job_Application__c app = insertApp('Interview Scheduled');

        Test.startTest();
        app.Rejection_Reason__c = getRejectionReason();
        app.Application_Stage__c = 'Rejected';
        update app;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Notify%'
        ];
        Assert.isTrue(tasks.size() >= 1,
            'Notify candidate task should be created');
    }

    @isTest
    static void test_noTask_whenStageDoesNotChange() {
        Job_Application__c app = insertApp('Screening');

        // clear any tasks from insert
        delete [SELECT Id FROM Task WHERE WhatId = :app.Id];

        Test.startTest();
        // update something other than stage
        app.Years_of_Experience__c = 5;
        update app;
        Test.stopTest();

        List<Task> tasks = getTasksForApp(app.Id);
        Assert.areEqual(0, tasks.size(),
            'No task should be created when stage does not change');
    }

    @isTest
    static void test_bulkUpdate_tasksCreatedForAll() {
        Contact c = getContact();
        Job_Opening__c jo = getJobOpening();

        List<Job_Application__c> apps =
            new List<Job_Application__c>();
        for(Integer i = 0; i < 50; i++) {
            apps.add(new Job_Application__c(
                Contact__c = c.Id,
                Job_Opening__c = jo.Id,
                Application_Stage__c = 'New',
                Applied_Date__c = Date.today()
            ));
        }
        insert apps;

        // move all to Shortlisted
        for(Job_Application__c app : apps) {
            app.Application_Stage__c = 'Shortlisted';
        }

        Test.startTest();
        update apps;
        Test.stopTest();

        // each should have a Schedule Interview task
        List<Task> tasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :apps
            AND Subject LIKE '%Schedule Interview%'
        ];
        Assert.areEqual(50, tasks.size(),
            'Schedule Interview task per application');
    }

    @isTest
    static void test_bulkShortlist_closesAllScreeningTasks() {
        Contact c = getContact();
        Job_Opening__c jo = getJobOpening();

        List<Job_Application__c> apps =
            new List<Job_Application__c>();
        for(Integer i = 0; i < 20; i++) {
            apps.add(new Job_Application__c(
                Contact__c = c.Id,
                Job_Opening__c = jo.Id,
                Application_Stage__c = 'New',
                Applied_Date__c = Date.today()
            ));
        }
        insert apps;

        // verify screening tasks created
        List<Task> screenTasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :apps
            AND Subject LIKE '%Screen%'
        ];
        Assert.areEqual(20, screenTasks.size(),
            '20 screening tasks should exist');

        // shortlist all
        for(Job_Application__c app : apps) {
            app.Application_Stage__c = 'Shortlisted';
        }

        Test.startTest();
        update apps;
        Test.stopTest();

        // all screening tasks should be closed
        List<Task> closedTasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :apps
            AND Subject LIKE '%Screen%'
            AND Status = 'Completed'
        ];
        Assert.areEqual(20, closedTasks.size(),
            'All 20 screening tasks should be closed');
    }
}