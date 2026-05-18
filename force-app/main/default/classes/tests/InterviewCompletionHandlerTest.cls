@IsTest
private class InterviewCompletionHandlerTest {

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

        Job_Opening__c jo = new Job_Opening__c(
            Job_Title__c = 'Test Developer',
            Account__c = acc.Id,
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering',
            Openings_Count__c = 1
        );
        insert jo;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'test@test.com',
            Contact_Type__c = 'Candidate',
            Candidate_Status__c = 'Active — Looking'
        );
        insert c;

        Job_Application__c app = new Job_Application__c(
            Contact__c = c.Id,
            Job_Opening__c = jo.Id,
            Application_Stage__c = 'Interview Scheduled',
            Applied_Date__c = Date.today()
        );
        insert app;

        Interview__c interview = new Interview__c(
            Job_Application__c = app.Id,
            Interview_Type__c = 'Technical Assessment',
            Interview_Round__c = 'Round 1',
            Mode__c = 'Video Call',
            Status__c = 'Scheduled',
            Interview_DateTime__c = DateTime.now().addDays(1),
            Meeting_Link__c = 'https://meet.google.com/test-link',
            Feedback_Submitted__c = false,
            Needs_Another_Round__c = false
        );
        insert interview;
    }

    private static Interview__c getInterview() {
        return [
            SELECT Id, Feedback_Submitted__c,
                   Needs_Another_Round__c,
                   Recommendation__c,
                   Job_Application__c
            FROM Interview__c
            LIMIT 1
        ];
    }

    private static Job_Application__c getApp() {
        return [
            SELECT Id, Application_Stage__c
            FROM Job_Application__c
            LIMIT 1
        ];
    }

    private static void applyFeedbackFields(Interview__c i) {
        i.Technical_Rating__c = 5;
        i.Communication_Rating__c = 5;
        i.Cultural_Fit_Rating__c = 5;
        i.Feedback__c = 'Great candidate';
    }

    private static void setRejectionReason(Id appId) {
        update new Job_Application__c(
            Id = appId,
            Rejection_Reason__c = 'Overqualified'
        );
    }

    @IsTest
    static void test_strongHire_movesToOfferPending() {
        Interview__c i = getInterview();
        i.Feedback_Submitted__c = true;
        i.Needs_Another_Round__c = false;
        i.Recommendation__c = 'Hire';
        applyFeedbackFields(i);

        Test.startTest();
        update i;
        Test.stopTest();

        Job_Application__c app = getApp();
        System.Assert.areEqual('Offer Pending',
            app.Application_Stage__c,
            'Hire should move to Offer Pending');
    }

    @IsTest
    static void test_hire_movesToOfferPending() {
        Interview__c i = getInterview();
        i.Feedback_Submitted__c = true;
        i.Needs_Another_Round__c = false;
        i.Recommendation__c = 'Hire';
        applyFeedbackFields(i);

        Test.startTest();
        update i;
        Test.stopTest();

        System.Assert.areEqual('Offer Pending',
            getApp().Application_Stage__c,
            'Hire should move to Offer Pending');
    }

    @IsTest
    static void test_noHire_movesToRejected() {
        Interview__c i = getInterview();
        setRejectionReason(i.Job_Application__c);
        i.Feedback_Submitted__c = true;
        i.Needs_Another_Round__c = false;
        i.Recommendation__c = 'No Hire';
        applyFeedbackFields(i);

        Test.startTest();
        update i;
        Test.stopTest();

        System.Assert.areEqual('Rejected',
            getApp().Application_Stage__c,
            'No Hire should move to Rejected');
    }

    @IsTest
    static void test_strongNoHire_movesToRejected() {
        Interview__c i = getInterview();
        setRejectionReason(i.Job_Application__c);
        i.Feedback_Submitted__c = true;
        i.Needs_Another_Round__c = false;
        i.Recommendation__c = 'No Hire';
        applyFeedbackFields(i);

        Test.startTest();
        update i;
        Test.stopTest();

        System.Assert.areEqual('Rejected',
            getApp().Application_Stage__c,
            'No Hire should move to Rejected');
    }

    @IsTest
    static void test_nonPassRecommendation_movesToRejected() {
        Interview__c i = getInterview();
        setRejectionReason(i.Job_Application__c);
        i.Feedback_Submitted__c = true;
        i.Needs_Another_Round__c = false;
        i.Recommendation__c = 'On the Fence';
        applyFeedbackFields(i);

        Test.startTest();
        update i;
        Test.stopTest();

        System.Assert.areEqual('Rejected',
            getApp().Application_Stage__c,
            'Non-pass recommendation should move to Rejected');
    }

    @IsTest
    static void test_needsAnotherRound_createsNextInterview() {
        Interview__c i = getInterview();
        i.Feedback_Submitted__c = true;
        i.Needs_Another_Round__c = true;
        i.Recommendation__c = 'On the Fence';
        applyFeedbackFields(i);

        Test.startTest();
        update i;
        Test.stopTest();

        System.Assert.areEqual('Interview Scheduled',
            getApp().Application_Stage__c,
            'Should move back to Interview Scheduled');

        List<Interview__c> interviews = [
            SELECT Id, Interview_Round__c, Status__c
            FROM Interview__c
            WHERE Job_Application__c = :getApp().Id
        ];

        System.Assert.areEqual(2, interviews.size(),
            'Round 2 interview should be created');

        Interview__c newInterview;
        for (Interview__c item : interviews) {
            if (item.Interview_Round__c == 'Round 2') {
                newInterview = item;
                break;
            }
        }

        System.Assert.isNotNull(newInterview,
            'New interview should be Round 2');
        System.Assert.areEqual('Scheduled',
            newInterview.Status__c,
            'New interview should be Scheduled');
    }

    @IsTest
    static void test_noChange_whenFeedbackNotSubmitted() {
        Interview__c i = getInterview();
        i.Technical_Rating__c = 4;

        Test.startTest();
        update i;
        Test.stopTest();

        System.Assert.areEqual('Interview Scheduled',
            getApp().Application_Stage__c,
            'Stage should not change without feedback submission');

        List<Interview__c> interviews = [
            SELECT Id FROM Interview__c
        ];
        System.Assert.areEqual(1, interviews.size(),
            'No new interview should be created');
    }

    @IsTest
    static void test_bulkInterviewCompletion() {
        Job_Opening__c jo = [
            SELECT Id
            FROM Job_Opening__c
            LIMIT 1
        ];

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Test ' + i,
                Email = 'bulk' + i + '@test.com',
                Contact_Type__c = 'Candidate',
                Candidate_Status__c = 'Active — Looking'
            ));
        }
        insert contacts;

        List<Job_Application__c> apps =
            new List<Job_Application__c>();
        for (Contact c : contacts) {
            apps.add(new Job_Application__c(
                Contact__c = c.Id,
                Job_Opening__c = jo.Id,
                Application_Stage__c = 'Interview Scheduled',
                Applied_Date__c = Date.today()
            ));
        }
        insert apps;

        List<Interview__c> interviews =
            new List<Interview__c>();
        for (Job_Application__c app : apps) {
            interviews.add(new Interview__c(
                Job_Application__c = app.Id,
                Interview_Type__c = 'Technical Assessment',
                Interview_Round__c = 'Round 1',
                Mode__c = 'Video Call',
                Status__c = 'Scheduled',
                Interview_DateTime__c = DateTime.now().addDays(1),
                Meeting_Link__c = 'https://meet.google.com/bulk-test',
                Feedback_Submitted__c = false,
                Needs_Another_Round__c = false
            ));
        }
        insert interviews;

        for (Interview__c i : interviews) {
            i.Feedback_Submitted__c = true;
            i.Recommendation__c = 'Hire';
            applyFeedbackFields(i);
        }

        Test.startTest();
        update interviews;
        Test.stopTest();

        List<Job_Application__c> updatedApps = [
            SELECT Application_Stage__c
            FROM Job_Application__c
            WHERE Id IN :apps
        ];

        for (Job_Application__c app : updatedApps) {
            System.Assert.areEqual('Offer Pending',
                app.Application_Stage__c,
                'All should be Offer Pending');
        }
    }
}
