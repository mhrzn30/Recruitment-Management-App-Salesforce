/**
 * @description Utility class for creating tasks in a bulk-safe, consistent manner
 * Used by recruitment automation handlers to create tasks for recruiters, hiring managers, and other users
 */
public with sharing class TaskCreationUtility {
    
    /**
     * @description Wrapper class to hold task creation parameters
     */
    public class TaskWrapper {
        public Id ownerId;
        public String subject;
        public Id whatId;        // Related record (Job_Application__c, Interview__c, etc.)
        public Id whoId;         // Related contact/lead
        public Date dueDate;
        public String priority;
        public String description;
        public String status;
        
        public TaskWrapper(Id ownerId, String subject, Id whatId, Date dueDate) {
            this.ownerId = ownerId;
            this.subject = subject;
            this.whatId = whatId;
            this.dueDate = dueDate;
            this.priority = 'Normal';
            this.status = 'Not Started';
        }
        
        public TaskWrapper setPriority(String priority) {
            this.priority = priority;
            return this;
        }
        
        public TaskWrapper setDescription(String description) {
            this.description = description;
            return this;
        }
        
        public TaskWrapper setWhoId(Id whoId) {
            this.whoId = whoId;
            return this;
        }
        
        public TaskWrapper setStatus(String status) {
            this.status = status;
            return this;
        }
    }
    
    /**
     * @description Creates tasks in bulk from a list of TaskWrapper objects
     * @param taskWrappers List of TaskWrapper objects containing task parameters
     * @return List<Task> Created tasks (not inserted if errors occur)
     */
    public static List<Task> createTasks(List<TaskWrapper> taskWrappers) {
        if (taskWrappers == null || taskWrappers.isEmpty()) {
            return new List<Task>();
        }
        
        List<Task> tasksToInsert = new List<Task>();
        
        for (TaskWrapper wrapper : taskWrappers) {
            // Validate required fields
            if (wrapper.ownerId == null || String.isBlank(wrapper.subject)) {
                continue; // Skip invalid task wrappers
            }
            
            Task newTask = new Task(
                OwnerId = wrapper.ownerId,
                Subject = wrapper.subject,
                WhatId = wrapper.whatId,
                WhoId = wrapper.whoId,
                ActivityDate = wrapper.dueDate != null ? wrapper.dueDate : Date.today().addDays(2),
                Priority = wrapper.priority != null ? wrapper.priority : 'Normal',
                Description = wrapper.description,
                Status = wrapper.status != null ? wrapper.status : 'Not Started'
            );
            
            tasksToInsert.add(newTask);
        }
        
        if (!tasksToInsert.isEmpty()) {
            try {
                insert tasksToInsert;
            } catch (DmlException e) {
                System.debug('Error creating tasks: ' + e.getMessage());
                // In production, you might want to log this to a custom object or send alert
                throw e;
            }
        }
        
        return tasksToInsert;
    }
    
    /**
     * @description Convenience method to create a single task
     * @param ownerId User who will own the task
     * @param subject Task subject
     * @param whatId Related record ID
     * @param dueDate Task due date
     * @return Task Created task
     */
    public static Task createTask(Id ownerId, String subject, Id whatId, Date dueDate) {
        List<TaskWrapper> wrappers = new List<TaskWrapper>{
            new TaskWrapper(ownerId, subject, whatId, dueDate)
        };
        
        List<Task> tasks = createTasks(wrappers);
        return tasks.isEmpty() ? null : tasks[0];
    }
    
    /**
     * @description Creates a high priority task
     * @param ownerId User who will own the task
     * @param subject Task subject
     * @param whatId Related record ID
     * @param dueDate Task due date
     * @param description Task description
     * @return Task Created task
     */
    public static Task createHighPriorityTask(Id ownerId, String subject, Id whatId, Date dueDate, String description) {
        TaskWrapper wrapper = new TaskWrapper(ownerId, subject, whatId, dueDate)
            .setPriority('High')
            .setDescription(description);
        
        List<Task> tasks = createTasks(new List<TaskWrapper>{ wrapper });
        return tasks.isEmpty() ? null : tasks[0];
    }
}