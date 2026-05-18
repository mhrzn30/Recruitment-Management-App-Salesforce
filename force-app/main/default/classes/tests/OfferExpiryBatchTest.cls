@IsTest
private class OfferExpiryBatchTest {

    @testSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Test Corp',
            Phone = '1234567890',
            Website = 'https://example.com',
            Account_Status__c = 'Active',
            Primary_Industry_Sector__c = 'Information Technology'
        
        );
        insert acc;

        Contact candidate = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'candidate@test.com',
            Contact_Type__c = 'Candidate',
            Candidate_Status__c = 'Active — Looking'
        );
        insert candidate;

        Job_Opening__c opening = new Job_Opening__c(
            Job_Title__c = 'Test Engineer',
            Account__c = acc.Id,
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering',
            Openings_Count__c = 1
        );
        insert opening;

        Job_Application__c app = new Job_Application__c(
            Job_Opening__c = opening.Id,
            Application_Stage__c = 'Offer Extended',
            Contact__c = candidate.Id,
            Candidate__c = candidate.Id,
            Applied_Date__c = Date.today().addDays(-7)
        );
        insert app;

        Offer__c expiredOffer = new Offer__c(
            Job_Application__c = app.Id,
            Offer_Status__c = 'Sent to Candidate',
            Offer_Letter_Sent__c = true,
            Offered_Salary__c = 100000,
            Offer_Date__c = Date.today().addDays(-10),
            Offer_Expiry_Date__c = Date.today().addDays(-1),
            Employment_Type__c = 'Full-Time',
            Offered_Designation__c = 'Software Engineer',
            Candidate__c = candidate.Id
        );

        Offer__c reminderOffer = new Offer__c(
            Job_Application__c = app.Id,
            Offer_Status__c = 'Sent to Candidate',
            Offer_Letter_Sent__c = true,
            Offered_Salary__c = 95000,
            Offer_Date__c = Date.today().addDays(-2),
            Offer_Expiry_Date__c = Date.today().addDays(1),
            Employment_Type__c = 'Full-Time',
            Offered_Designation__c = 'Software Engineer'
        );

        Offer__c futureOffer = new Offer__c(
            Job_Application__c = app.Id,
            Offer_Status__c = 'Sent to Candidate',
            Offer_Letter_Sent__c = true,
            Offered_Salary__c = 90000,
            Offer_Date__c = Date.today().addDays(-1),
            Offer_Expiry_Date__c = Date.today().addDays(10),
            Employment_Type__c = 'Full-Time',
            Offered_Designation__c = 'Software Engineer'
        );

        insert new List<Offer__c>{
            expiredOffer,
            reminderOffer,
            futureOffer
        };
    }

    @IsTest
    static void test_expiredOfferIsUpdated() {
        Test.startTest();
        Database.executeBatch(new CloseExpiredOffersBatch(), 200);
        Test.stopTest();

        Offer__c expired = [
            SELECT Offer_Status__c
            FROM Offer__c
            WHERE Offer_Expiry_Date__c = :Date.today().addDays(-1)
            LIMIT 1
        ];
        System.Assert.areEqual('Expired', expired.Offer_Status__c,
            'Expired offers should be set to Expired');

        Job_Application__c app = [
            SELECT Application_Stage__c
            FROM Job_Application__c
            LIMIT 1
        ];
        System.Assert.areEqual('On Hold', app.Application_Stage__c,
            'Application should move to On Hold');
    }

    @IsTest
    static void test_reminderBatchLeavesStatus() {
        Test.startTest();
        Database.executeBatch(new OfferExpiryReminderBatch(), 200);
        Test.stopTest();

        Offer__c reminder = [
            SELECT Offer_Status__c
            FROM Offer__c
            WHERE Offer_Expiry_Date__c = :Date.today().addDays(1)
            LIMIT 1
        ];
        System.Assert.areEqual('Sent to Candidate', reminder.Offer_Status__c,
            'Reminder batch should not change offer status');
    }

    @IsTest
    static void test_scheduler() {
        Test.startTest();
        String cronExp = '0 0 0 * * ?';
        System.schedule(
            'Test Offer Expiry Scheduler',
            cronExp,
            new OfferExpiryScheduler()
        );
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Test Offer Expiry Scheduler'
        ];
        System.Assert.areEqual(1, jobs.size(),
            'Scheduler should be registered');
    }
}
