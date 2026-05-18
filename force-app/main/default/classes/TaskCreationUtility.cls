public without sharing class TaskCreationUtility {

    public class TaskWrapper {
        public Id ownerId;
        public String subject;
        public Id whatId;
        public Id whoId;
        public Date dueDate;
        public String priority;
        public String description;

        public TaskWrapper(
            Id ownerId,
            String subject,
            Id whatId,
            Date dueDate
        ) {
            this.ownerId = ownerId;
            this.subject = subject;
            this.whatId = whatId;
            this.dueDate = dueDate;
            this.priority = 'Normal';
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
    }

    // ── Create Tasks ──────────────────────────────────────────

    public static List<Task> createTasks(
        List<TaskWrapper> wrappers
    ) {
        if(wrappers == null || wrappers.isEmpty()) {
            return new List<Task>();
        }

        List<Task> toInsert = new List<Task>();

        for(TaskWrapper w : wrappers) {
            if(w.ownerId == null || String.isBlank(w.subject)) {
                continue;
            }
            toInsert.add(new Task(
                OwnerId = w.ownerId,
                Subject = w.subject,
                WhatId = w.whatId,
                WhoId = w.whoId,
                ActivityDate = w.dueDate ?? Date.today().addDays(2),
                Priority = w.priority ?? 'Normal',
                Description = w.description,
                Status = 'Not Started'
            ));
        }

        if(!toInsert.isEmpty()) {
            insert toInsert;
        }
        return toInsert;
    }

    // ── Close Tasks ───────────────────────────────────────────

    /**
     * Closes all open tasks matching a subject keyword
     * on a specific record — used when stage changes
     * make a task irrelevant
     *
     * Example: when candidate moves to Shortlisted
     * close the "Screen & Shortlist" task automatically
     */
    public static void closeTasks(
        Set<Id> whatIds,
        String subjectKeyword
    ) {
        if(whatIds.isEmpty() || String.isBlank(subjectKeyword)) {
            return;
        }

        List<Task> openTasks = [
            SELECT Id, Status
            FROM Task
            WHERE WhatId IN :whatIds
            AND Subject LIKE :('%' + subjectKeyword + '%')
            AND Status != 'Completed'
            AND IsClosed = false
        ];

        if(openTasks.isEmpty()) return;

        for(Task t : openTasks) {
            t.Status = 'Completed';
        }
        update openTasks;
    }
}