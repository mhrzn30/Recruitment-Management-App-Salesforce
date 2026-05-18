trigger JobApplicationTaskTrigger on Job_Application__c (
    after insert,
    after update
) {
    Set<Id> joIds = new Set<Id>();
    Set<Id> contactIds = new Set<Id>();

    for(Job_Application__c app : Trigger.new) {
        if(app.Job_Opening__c != null)
            joIds.add(app.Job_Opening__c);
        if(app.Contact__c != null)
            contactIds.add(app.Contact__c);
    }

    Map<Id, Job_Opening__c> joMap =
        new Map<Id, Job_Opening__c>([
            SELECT Id, Job_Title__c,
                   Recruiter__c,
                   Account__r.Name
            FROM Job_Opening__c
            WHERE Id IN :joIds
        ]);

    Map<Id, Contact> contactMap =
        new Map<Id, Contact>([
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id IN :contactIds
        ]);

    // ── INSERT ────────────────────────────────────────────────
    if(Trigger.isInsert) {
        List<TaskCreationUtility.TaskWrapper> wrappers =
            new List<TaskCreationUtility.TaskWrapper>();

        for(Job_Application__c app : Trigger.new) {
            Job_Opening__c jo = joMap.get(app.Job_Opening__c);
            Contact c = contactMap.get(app.Contact__c);
            if(jo == null || c == null) continue;

            String candidateName =
                c.FirstName + ' ' + c.LastName;
            Id taskOwner = jo.Recruiter__c != null
                ? jo.Recruiter__c
                : UserInfo.getUserId();

            wrappers.add(
                new TaskCreationUtility.TaskWrapper(
                    taskOwner,
                    'Screen & Shortlist — ' + candidateName +
                        ' for ' + jo.Job_Title__c,
                    app.Id,
                    Date.today().addDays(2)
                )
                .setPriority('High')
                .setDescription(
                    'New application received from ' +
                    candidateName + ' for ' + jo.Job_Title__c +
                    ' at ' + jo.Account__r.Name +
                    '. Review CV and shortlist if suitable.'
                )
                // .setWhoId(app.Contact__c)
            );
        }

        TaskCreationUtility.createTasks(wrappers);
    }

    // ── UPDATE ────────────────────────────────────────────────
    if(Trigger.isUpdate) {
        Set<Id> shortlistedIds = new Set<Id>();
        List<TaskCreationUtility.TaskWrapper> wrappers =
            new List<TaskCreationUtility.TaskWrapper>();

        for(Job_Application__c app : Trigger.new) {
            Job_Application__c old = Trigger.oldMap.get(app.Id);
            if(app.Application_Stage__c ==
               old.Application_Stage__c) continue;

            Job_Opening__c jo = joMap.get(app.Job_Opening__c);
            Contact c = contactMap.get(app.Contact__c);
            if(jo == null || c == null) continue;

            String candidateName =
                c.FirstName + ' ' + c.LastName;
            Id taskOwner = jo.Recruiter__c != null
                ? jo.Recruiter__c
                : UserInfo.getUserId();

            switch on app.Application_Stage__c {

                when 'Shortlisted' {
                    shortlistedIds.add(app.Id);
                    wrappers.add(
                        new TaskCreationUtility.TaskWrapper(
                            taskOwner,
                            'Schedule Interview — ' +
                                candidateName,
                            app.Id,
                            Date.today().addDays(2)
                        )
                        .setPriority('High')
                        .setDescription(
                            candidateName +
                            ' shortlisted for ' +
                            jo.Job_Title__c +
                            '. Schedule interview and ' +
                            'assign hiring manager.'
                        )
                        // .setWhoId(app.Contact__c)
                    );
                }

                when 'Offer Pending' {
                    wrappers.add(
                        new TaskCreationUtility.TaskWrapper(
                            taskOwner,
                            'Prepare Offer — ' + candidateName,
                            app.Id,
                            Date.today().addDays(2)
                        )
                        .setPriority('High')
                        .setDescription(
                            candidateName +
                            ' cleared interviews for ' +
                            jo.Job_Title__c +
                            '. Prepare and send offer letter.'
                        )
                        // .setWhoId(app.Contact__c)
                    );
                }

                when 'Hired' {
                    wrappers.add(
                        new TaskCreationUtility.TaskWrapper(
                            taskOwner,
                            'Raise Invoice — ' +
                                candidateName +
                                ' placed at ' +
                                jo.Account__r.Name,
                            app.Id,
                            Date.today().addDays(3)
                        )
                        .setPriority('High')
                        .setDescription(
                            candidateName +
                            ' successfully placed at ' +
                            jo.Account__r.Name +
                            ' for ' + jo.Job_Title__c +
                            '. Raise placement invoice.'
                        )
                        // .setWhoId(app.Contact__c)
                    );
                }

                when 'Rejected' {
                    wrappers.add(
                        new TaskCreationUtility.TaskWrapper(
                            taskOwner,
                            'Notify Candidate — ' +
                                candidateName,
                            app.Id,
                            Date.today().addDays(1)
                        )
                        .setPriority('Normal')
                        .setDescription(
                            'Inform ' + candidateName +
                            ' that their application for ' +
                            jo.Job_Title__c +
                            ' was unsuccessful.'
                        )
                        // .setWhoId(app.Contact__c)
                    );
                }
            }
        }

        if(!shortlistedIds.isEmpty()) {
            TaskCreationUtility.closeTasks(
                shortlistedIds, 'Screen'
            );
        }

        if(!wrappers.isEmpty()) {
            TaskCreationUtility.createTasks(wrappers);
        }
    }
}