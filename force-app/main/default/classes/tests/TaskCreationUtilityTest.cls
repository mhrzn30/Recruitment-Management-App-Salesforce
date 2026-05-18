@isTest
private class TaskCreationUtilityTest {

    @testSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Test Company',
            Account_Status__c = 'Active',
            Primary_Industry_Sector__c = 'Information Technology'
        );
        insert acc;

        Job_Opening__c jo = new Job_Opening__c(
            Job_Title__c = 'Test Developer',
            Status__c = 'Open',
            Openings_Count__c = 1,
            Account__c = acc.Id,
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering'
        );
        insert jo;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'test@example.com',
            Contact_Type__c = 'Candidate',
            Candidate_Status__c = 'Active — Looking'
        );
        insert c;

        Job_Application__c app = new Job_Application__c(
            Job_Opening__c = jo.Id,
            Contact__c = c.Id,
            Application_Stage__c = 'New',
            Applied_Date__c = Date.today()
        );
        insert app;
    }

    // ── helpers ──────────────────────────────────────────────

    private static Job_Application__c getApp() {
        return [
            SELECT Id, Contact__c
            FROM Job_Application__c
            LIMIT 1
        ];
    }

    private static User getUser() {
        return [
            SELECT Id FROM User
            WHERE IsActive = true
            LIMIT 1
        ];
    }

    // ── createTasks Tests ─────────────────────────────────────

    @isTest
    static void test_createTasks_bulkCreation() {
        Job_Application__c app = getApp();
        User u = getUser();

        List<TaskCreationUtility.TaskWrapper> wrappers =
            new List<TaskCreationUtility.TaskWrapper>();

        for(Integer i = 0; i < 5; i++) {
            wrappers.add(
                new TaskCreationUtility.TaskWrapper(
                    u.Id,
                    'Bulk Task ' + i,
                    app.Id,
                    Date.today().addDays(i + 1)
                )
                .setPriority(i < 2 ? 'High' : 'Normal')
                .setDescription('Description ' + i)
            );
        }

        Test.startTest();
        List<Task> created =
            TaskCreationUtility.createTasks(wrappers);
        Test.stopTest();

        Assert.areEqual(5, created.size(),
            '5 tasks should be created');

        List<Task> inDb = [
            SELECT Id, Priority FROM Task
            WHERE WhatId = :app.Id
        ];
        Assert.areEqual(5, inDb.size(),
            '5 tasks should exist in database');

        Integer highCount = 0;
        for(Task t : inDb) {
            if(t.Priority == 'High') highCount++;
        }
        Assert.areEqual(2, highCount,
            '2 tasks should be High priority');
    }

    @isTest
    static void test_createTasks_nullInput_returnsEmpty() {
        Test.startTest();
        List<Task> created =
            TaskCreationUtility.createTasks(null);
        Test.stopTest();

        Assert.areEqual(0, created.size(),
            'Should return empty list for null input');
    }

    @isTest
    static void test_createTasks_emptyInput_returnsEmpty() {
        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>()
        );
        Test.stopTest();

        Assert.areEqual(0, created.size(),
            'Should return empty list for empty input');
    }

    @isTest
    static void test_createTasks_invalidWrapper_skipped() {
        Job_Application__c app = getApp();

        // null ownerId — invalid wrapper
        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                null,
                'Invalid Task',
                app.Id,
                Date.today()
            );

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual(0, created.size(),
            'Invalid wrapper should be skipped');

        List<Task> inDb = [
            SELECT Id FROM Task WHERE WhatId = :app.Id
        ];
        Assert.areEqual(0, inDb.size(),
            'No tasks should be in database');
    }

    @isTest
    static void test_createTasks_blankSubject_skipped() {
        Job_Application__c app = getApp();
        User u = getUser();

        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                u.Id,
                '',   // blank subject — invalid
                app.Id,
                Date.today()
            );

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual(0, created.size(),
            'Blank subject wrapper should be skipped');
    }

    // ── TaskWrapper Tests ─────────────────────────────────────

    @isTest
    static void test_wrapper_defaultValues() {
        Job_Application__c app = getApp();
        User u = getUser();

        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                u.Id,
                'Default Task',
                app.Id,
                null  // null date → defaults to today + 2
            );

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual(1, created.size(),
            'Task should be created');
        Assert.areEqual(Date.today().addDays(2),
            created[0].ActivityDate,
            'Default due date should be today + 2');
        Assert.areEqual('Normal', created[0].Priority,
            'Default priority should be Normal');
        Assert.areEqual('Not Started', created[0].Status,
            'Default status should be Not Started');
    }

    @isTest
    static void test_wrapper_setPriority() {
        Job_Application__c app = getApp();
        User u = getUser();

        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                u.Id, 'High Priority Task',
                app.Id, Date.today()
            )
            .setPriority('High');

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual('High', created[0].Priority,
            'Priority should be High');
    }

    @isTest
    static void test_wrapper_setDescription() {
        Job_Application__c app = getApp();
        User u = getUser();

        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                u.Id, 'Task with Description',
                app.Id, Date.today()
            )
            .setDescription('Test description');

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual('Test description',
            created[0].Description,
            'Description should match');
    }

    @isTest
    static void test_wrapper_setWhoId() {
        Job_Application__c app = getApp();
        User u = getUser();

        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                u.Id, 'Task with WhoId',
                app.Id, Date.today()
            )
            .setWhoId(app.Contact__c);

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual(app.Contact__c, created[0].WhoId,
            'WhoId should be set to Contact');
    }

    @isTest
    static void test_wrapper_methodChaining() {
        Job_Application__c app = getApp();
        User u = getUser();

        // test all setters chained together
        TaskCreationUtility.TaskWrapper wrapper =
            new TaskCreationUtility.TaskWrapper(
                u.Id, 'Chained Task',
                app.Id, Date.today().addDays(5)
            )
            .setPriority('High')
            .setDescription('Chained description')
            .setWhoId(app.Contact__c);

        Test.startTest();
        List<Task> created = TaskCreationUtility.createTasks(
            new List<TaskCreationUtility.TaskWrapper>{ wrapper }
        );
        Test.stopTest();

        Assert.areEqual(1, created.size(),
            'Task should be created');
        Assert.areEqual('High', created[0].Priority,
            'Priority should be High');
        Assert.areEqual('Chained description',
            created[0].Description,
            'Description should match');
        Assert.areEqual(app.Contact__c, created[0].WhoId,
            'WhoId should match');
        Assert.areEqual(Date.today().addDays(5),
            created[0].ActivityDate,
            'Due date should match');
    }

    // ── closeTasks Tests ──────────────────────────────────────

    @isTest
    static void test_closeTasks_closesMatchingTasks() {
        Job_Application__c app = getApp();
        User u = getUser();

        // create a screening task
        insert new Task(
            OwnerId = u.Id,
            Subject = 'Screen & Shortlist — Test Candidate',
            WhatId = app.Id,
            ActivityDate = Date.today().addDays(2),
            Status = 'Not Started',
            Priority = 'High'
        );

        Test.startTest();
        TaskCreationUtility.closeTasks(
            new Set<Id>{ app.Id },
            'Screen'
        );
        Test.stopTest();

        Task closed = [
            SELECT Status FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Screen%'
            LIMIT 1
        ];
        Assert.areEqual('Completed', closed.Status,
            'Matching task should be closed');
    }

    @isTest
    static void test_closeTasks_doesNotCloseOtherTasks() {
        Job_Application__c app = getApp();
        User u = getUser();

        // create two tasks — one screen, one interview
        insert new List<Task>{
            new Task(
                OwnerId = u.Id,
                Subject = 'Screen & Shortlist — Test',
                WhatId = app.Id,
                ActivityDate = Date.today(),
                Status = 'Not Started',
                Priority = 'High'
            ),
            new Task(
                OwnerId = u.Id,
                Subject = 'Schedule Interview — Test',
                WhatId = app.Id,
                ActivityDate = Date.today(),
                Status = 'Not Started',
                Priority = 'High'
            )
        };

        Test.startTest();
        TaskCreationUtility.closeTasks(
            new Set<Id>{ app.Id },
            'Screen'
        );
        Test.stopTest();

        // screen task closed
        Task screenTask = [
            SELECT Status FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Screen%'
            LIMIT 1
        ];
        Assert.areEqual('Completed', screenTask.Status,
            'Screen task should be closed');

        // interview task untouched
        Task interviewTask = [
            SELECT Status FROM Task
            WHERE WhatId = :app.Id
            AND Subject LIKE '%Interview%'
            LIMIT 1
        ];
        Assert.areEqual('Not Started', interviewTask.Status,
            'Interview task should not be touched');
    }

    @isTest
    static void test_closeTasks_emptyIds_noError() {
        Test.startTest();
        // should not throw any error
        TaskCreationUtility.closeTasks(
            new Set<Id>(),
            'Screen'
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should handle empty set gracefully');
    }

    @isTest
    static void test_closeTasks_blankKeyword_noError() {
        Job_Application__c app = getApp();

        Test.startTest();
        TaskCreationUtility.closeTasks(
            new Set<Id>{ app.Id },
            ''
        );
        Test.stopTest();

        Assert.isTrue(true,
            'Should handle blank keyword gracefully');
    }

    @isTest
    static void test_closeTasks_alreadyCompleted_noError() {
        Job_Application__c app = getApp();
        User u = getUser();

        // insert already completed task
        insert new Task(
            OwnerId = u.Id,
            Subject = 'Screen & Shortlist — Already Done',
            WhatId = app.Id,
            ActivityDate = Date.today(),
            Status = 'Completed',
            Priority = 'High'
        );

        Test.startTest();
        // should not error on already completed tasks
        TaskCreationUtility.closeTasks(
            new Set<Id>{ app.Id },
            'Screen'
        );
        Test.stopTest();

        Task t = [
            SELECT Status FROM Task
            WHERE WhatId = :app.Id
            LIMIT 1
        ];
        Assert.areEqual('Completed', t.Status,
            'Already completed task should remain Completed');
    }

    @isTest
    static void test_closeTasks_bulk() {
        User u = getUser();
        Job_Opening__c jo = [
            SELECT Id FROM Job_Opening__c LIMIT 1
        ];
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        // create 20 applications with screening tasks
        List<Job_Application__c> apps =
            new List<Job_Application__c>();
        for(Integer i = 0; i < 20; i++) {
            apps.add(new Job_Application__c(
                Job_Opening__c = jo.Id,
                Contact__c = c.Id,
                Application_Stage__c = 'New',
                Applied_Date__c = Date.today()
            ));
        }
        insert apps;

        List<Task> tasks = new List<Task>();
        for(Job_Application__c app : apps) {
            tasks.add(new Task(
                OwnerId = u.Id,
                Subject = 'Screen & Shortlist — Bulk Test',
                WhatId = app.Id,
                ActivityDate = Date.today(),
                Status = 'Not Started',
                Priority = 'High'
            ));
        }
        insert tasks;

        Set<Id> appIds = new Map<Id, Job_Application__c>(apps).keySet();

        Test.startTest();
        TaskCreationUtility.closeTasks(appIds, 'Screen');
        Test.stopTest();

        List<Task> closed = [
            SELECT Id FROM Task
            WHERE WhatId IN :apps
            AND Status = 'Completed'
        ];
        Assert.areEqual(20, closed.size(),
            'All 20 screening tasks should be closed');
    }
}