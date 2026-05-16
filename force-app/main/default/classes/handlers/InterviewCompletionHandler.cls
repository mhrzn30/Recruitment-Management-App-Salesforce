public with sharing class InterviewCompletionHandler {

    private static final Set<String> PASS_RECOMMENDATIONS =
        new Set<String>{ 'Strong Hire', 'Hire' };

    private static final Set<String> FAIL_RECOMMENDATIONS =
        new Set<String>{ 'No Hire', 'Strong No Hire' };

    public static void handle(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        List<Interview__c> completedInterviews =
            new List<Interview__c>();

        for (Interview__c interview : newList) {
            Interview__c oldInterview = oldMap.get(interview.Id);
            if (oldInterview == null) continue;

            Boolean feedbackJustSubmitted =
                !oldInterview.Feedback_Submitted__c
                && interview.Feedback_Submitted__c;

            if (feedbackJustSubmitted) {
                completedInterviews.add(interview);
            }
        }

        if (completedInterviews.isEmpty()) return;

        Set<Id> appIds = new Set<Id>();
        for (Interview__c i : completedInterviews) {
            if (i.Job_Application__c != null) {
                appIds.add(i.Job_Application__c);
            }
        }

        if (appIds.isEmpty()) return;

        Map<Id, Integer> roundCountMap = getRoundCounts(appIds);

        List<Interview__c> interviewsToCreate =
            new List<Interview__c>();
        List<Job_Application__c> appsToUpdate =
            new List<Job_Application__c>();

        for (Interview__c interview : completedInterviews) {
            Id appId = interview.Job_Application__c;
            if (appId == null) continue;

            if (interview.Needs_Another_Round__c) {
                Integer currentRound = roundCountMap.containsKey(appId)
                    ? roundCountMap.get(appId)
                    : 1;
                Integer nextRound = currentRound + 1;

                interviewsToCreate.add(
                    buildNextRoundInterview(interview, appId, nextRound)
                );

                appsToUpdate.add(new Job_Application__c(
                    Id = appId,
                    Application_Stage__c = 'Interview Scheduled'
                ));
            } else {
                String stage = getOutcomeStage(interview.Recommendation__c);
                appsToUpdate.add(new Job_Application__c(
                    Id = appId,
                    Application_Stage__c = stage
                ));
            }
        }

        if (!interviewsToCreate.isEmpty()) {
            insert interviewsToCreate;
        }
        if (!appsToUpdate.isEmpty()) {
            update appsToUpdate;
        }
    }

    private static Map<Id, Integer> getRoundCounts(
        Set<Id> appIds
    ) {
        Map<Id, Integer> countMap = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT Job_Application__c appId,
                   COUNT(Id) total
            FROM Interview__c
            WHERE Job_Application__c IN :appIds
            GROUP BY Job_Application__c
        ]) {
            countMap.put(
                (Id)ar.get('appId'),
                (Integer)ar.get('total')
            );
        }

        return countMap;
    }

    private static Interview__c buildNextRoundInterview(
        Interview__c previous,
        Id appId,
        Integer roundNumber
    ) {
        String roundLabel = roundNumber >= 4
            ? 'Final Round'
            : 'Round ' + roundNumber;

        String meetingLink = previous.Meeting_Link__c;
        if (previous.Mode__c == 'Video Call'
            && String.isBlank(meetingLink)) {
            meetingLink = 'https://meet.google.com/new';
        }

        return new Interview__c(
            Job_Application__c = appId,
            Interview_Type__c = previous.Interview_Type__c,
            Interview_Round__c = roundLabel,
            Mode__c = previous.Mode__c,
            Status__c = 'Scheduled',
            Interview_DateTime__c = DateTime.now().addDays(3),
            Interviewer__c = previous.Interviewer__c,
            Meeting_Link__c = meetingLink,
            Venue__c = previous.Venue__c,
            Needs_Another_Round__c = false
        );
    }

    private static String getOutcomeStage(String recommendation) {
        if (PASS_RECOMMENDATIONS.contains(recommendation)) {
            return 'Offer Pending';
        }
        if (FAIL_RECOMMENDATIONS.contains(recommendation)) {
            return 'Rejected';
        }
        return 'Rejected';
    }
}
