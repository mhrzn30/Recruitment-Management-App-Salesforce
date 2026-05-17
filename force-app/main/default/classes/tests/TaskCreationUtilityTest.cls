/**
 * @description Test class for TaskCreationUtility
 */
@isTest
private class TaskCreationUtilityTest {
    
    @testSetup
    static void setup() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Company',
            Phone = '555-0100'
        );
        insert testAccount;
        
        // Create test job opening with all required fields
        Job_Opening__c jobOpening = new Job_Opening__c(
            Job_Title__c = 'Test Developer',
            Status__c = 'Open',
            Openings_Count__c = 1,
            Account__c = testAccount.Id,
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering'
        );
        insert jobOpening;
        
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'test@example.com',
            Contact_Type__c = 'Candidate'
        );
        insert testContact;
        
        // Create test job application
        Job_Application__c application = new Job_Application__c(
            Job_Opening__c = jobOpening.Id,
            Contact__c = testContact.Id,
            Application_Stage__c = 'New'
        );
        insert application;
    }
    
    @isTest
    static void testCreateSingleTask() {
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        Test.startTest();
        Task createdTask = TaskCreationUtility.createTask(
            testUser.Id,
            'Test Task',
            app.Id,
            Date.today().addDays(2)
        );
        Test.stopTest();
        
        // Verify task was created
        System.assertNotEquals(null, createdTask, 'Task should be created');
        System.assertEquals(testUser.Id, createdTask.OwnerId, 'Task owner should match');
        System.assertEquals('Test Task', createdTask.Subject, 'Task subject should match');
        System.assertEquals(app.Id, createdTask.WhatId, 'Task should be related to application');
        System.assertEquals(Date.today().addDays(2), createdTask.ActivityDate, 'Due date should match');
        
        // Verify task exists in database
        List<Task> tasks = [SELECT Id, Subject FROM Task WHERE WhatId = :app.Id];
        System.assertEquals(1, tasks.size(), 'One task should exist');
    }
    
    @isTest
    static void testCreateHighPriorityTask() {
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        Test.startTest();
        Task createdTask = TaskCreationUtility.createHighPriorityTask(
            testUser.Id,
            'Urgent Task',
            app.Id,
            Date.today().addDays(1),
            'This is a high priority task'
        );
        Test.stopTest();
        
        // Verify task properties
        System.assertEquals('High', createdTask.Priority, 'Priority should be High');
        System.assertEquals('This is a high priority task', createdTask.Description, 'Description should match');
        System.assertEquals('Urgent Task', createdTask.Subject, 'Subject should match');
    }
    
    @isTest
    static void testCreateBulkTasks() {
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        List<TaskCreationUtility.TaskWrapper> wrappers = new List<TaskCreationUtility.TaskWrapper>();
        
        // Create 5 task wrappers
        for (Integer i = 0; i < 5; i++) {
            TaskCreationUtility.TaskWrapper wrapper = new TaskCreationUtility.TaskWrapper(
                testUser.Id,
                'Bulk Task ' + i,
                app.Id,
                Date.today().addDays(i + 1)
            );
            wrapper.setPriority(i < 2 ? 'High' : 'Normal');
            wrapper.setDescription('Description for task ' + i);
            wrappers.add(wrapper);
        }
        
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(wrappers);
        Test.stopTest();
        
        // Verify all tasks were created
        System.assertEquals(5, createdTasks.size(), '5 tasks should be created');
        
        // Verify tasks in database
        List<Task> tasks = [SELECT Id, Subject, Priority FROM Task WHERE WhatId = :app.Id ORDER BY Subject];
        System.assertEquals(5, tasks.size(), '5 tasks should exist in database');
        
        // Verify priority settings
        Integer highPriorityCount = 0;
        for (Task t : tasks) {
            if (t.Priority == 'High') {
                highPriorityCount++;
            }
        }
        System.assertEquals(2, highPriorityCount, '2 tasks should have High priority');
    }
    
    @isTest
    static void testTaskWrapperWithWhoId() {
        Job_Application__c app = [SELECT Id, Contact__c FROM Job_Application__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        TaskCreationUtility.TaskWrapper wrapper = new TaskCreationUtility.TaskWrapper(
            testUser.Id,
            'Task with Contact',
            app.Id,
            Date.today().addDays(1)
        );
        wrapper.setWhoId(app.Contact__c);
        wrapper.setDescription('Task description');
        
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(new List<TaskCreationUtility.TaskWrapper>{ wrapper });
        Test.stopTest();
        
        // Verify WhoId was set
        System.assertEquals(1, createdTasks.size(), 'Task should be created');
        System.assertEquals(app.Contact__c, createdTasks[0].WhoId, 'WhoId should be set to Contact');
    }
    
    @isTest
    static void testCreateTasksWithNullList() {
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(null);
        Test.stopTest();
        
        // Should return empty list without error
        System.assertEquals(0, createdTasks.size(), 'Should return empty list for null input');
    }
    
    @isTest
    static void testCreateTasksWithEmptyList() {
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(new List<TaskCreationUtility.TaskWrapper>());
        Test.stopTest();
        
        // Should return empty list without error
        System.assertEquals(0, createdTasks.size(), 'Should return empty list for empty input');
    }
    
    @isTest
    static void testCreateTasksWithInvalidWrapper() {
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];
        
        // Create wrapper with null ownerId (invalid)
        TaskCreationUtility.TaskWrapper wrapper = new TaskCreationUtility.TaskWrapper(
            null,  // Invalid - null ownerId
            'Invalid Task',
            app.Id,
            Date.today()
        );
        
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(new List<TaskCreationUtility.TaskWrapper>{ wrapper });
        Test.stopTest();
        
        // Should skip invalid wrapper and return empty list
        System.assertEquals(0, createdTasks.size(), 'Invalid wrapper should be skipped');
        
        // Verify no tasks created in database
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :app.Id];
        System.assertEquals(0, tasks.size(), 'No tasks should be created for invalid wrapper');
    }
    
    @isTest
    static void testDefaultDueDate() {
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        // Create wrapper with null due date
        TaskCreationUtility.TaskWrapper wrapper = new TaskCreationUtility.TaskWrapper(
            testUser.Id,
            'Task with default due date',
            app.Id,
            null  // null due date should default to today + 2
        );
        
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(new List<TaskCreationUtility.TaskWrapper>{ wrapper });
        Test.stopTest();
        
        // Verify default due date is today + 2 days
        System.assertEquals(1, createdTasks.size(), 'Task should be created');
        System.assertEquals(Date.today().addDays(2), createdTasks[0].ActivityDate, 'Default due date should be today + 2 days');
    }
    
    @isTest
    static void testTaskStatusAndPriority() {
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        TaskCreationUtility.TaskWrapper wrapper = new TaskCreationUtility.TaskWrapper(
            testUser.Id,
            'Custom Status Task',
            app.Id,
            Date.today()
        );
        wrapper.setStatus('In Progress');
        wrapper.setPriority('Low');
        
        Test.startTest();
        List<Task> createdTasks = TaskCreationUtility.createTasks(new List<TaskCreationUtility.TaskWrapper>{ wrapper });
        Test.stopTest();
        
        // Verify custom status and priority
        System.assertEquals('In Progress', createdTasks[0].Status, 'Status should be In Progress');
        System.assertEquals('Low', createdTasks[0].Priority, 'Priority should be Low');
    }
}