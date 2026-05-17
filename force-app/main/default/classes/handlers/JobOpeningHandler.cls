/**
 * @description Handler class for Job_Opening__c trigger
 * Manages automation logic for job opening lifecycle events
 */
public with sharing class JobOpeningHandler {
    
    /**
     * @description Creates a task for the recruiter when a new job opening is created
     * @param newJobOpenings List of newly created Job_Opening__c records
     */
    public static void notifyRecruiterOnNewJobOpening(List<Job_Opening__c> newJobOpenings) {
        if (newJobOpenings == null || newJobOpenings.isEmpty()) {
            return;
        }
        
        List<TaskCreationUtility.TaskWrapper> taskWrappers = new List<TaskCreationUtility.TaskWrapper>();
        
        for (Job_Opening__c jobOpening : newJobOpenings) {
            // Determine the recruiter owner (use Recruiter__c if present; otherwise CreatedById)
            Id ownerId = (Id) jobOpening.get('Recruiter__c');
            if (ownerId == null) {
                ownerId = jobOpening.CreatedById;
            }
            if (ownerId == null) {
                continue;
            }
            
            // Build task subject with job title
            String jobTitle = String.isNotBlank(jobOpening.Job_Title__c) 
                ? jobOpening.Job_Title__c 
                : jobOpening.Name;
            String subject = 'New Job Opening Created - ' + jobTitle;
            
            // Create task wrapper
            TaskCreationUtility.TaskWrapper wrapper = new TaskCreationUtility.TaskWrapper(
                ownerId,
                subject,
                jobOpening.Id,
                Date.today().addDays(1)
            );
            
            wrapper.setPriority('Normal');
            wrapper.setDescription(
                'A new job opening has been created. Please review the details and start sourcing candidates for this position.\n\n' +
                'Job Title: ' + jobTitle + '\n' +
                'Department: ' + (String.isNotBlank(jobOpening.Department__c) ? jobOpening.Department__c : 'Not specified') + '\n' +
                'Status: ' + (String.isNotBlank(jobOpening.Status__c) ? jobOpening.Status__c : 'Open')
            );
            
            taskWrappers.add(wrapper);
        }
        
        // Create all tasks in bulk
        if (!taskWrappers.isEmpty()) {
            try {
                TaskCreationUtility.createTasks(taskWrappers);
            } catch (Exception e) {
                System.debug('Error creating job opening tasks: ' + e.getMessage());
                // In production, consider logging to a custom object or sending alert
                throw e;
            }
        }
    }
}
