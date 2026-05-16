@IsTest
private class CloseExpiredJobOpeningsBatchTest {

    @testSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Test Corp',
            Account_Status__c = 'Active',
            Primary_Industry_Sector__c = 'Information Technology'
        );
        insert acc;

        Job_Opening__c expiredJo = new Job_Opening__c(
            Job_Title__c = 'Expired Role',
            Account__c = acc.Id,
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering',
            Openings_Count__c = 1,
            Application_Deadline__c = Date.today().addDays(-5)
        );

        Job_Opening__c activeJo = new Job_Opening__c(
            Job_Title__c = 'Active Role',
            Account__c = acc.Id,
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Department__c = 'Engineering',
            Openings_Count__c = 1,
            Application_Deadline__c = Date.today().addDays(30)
        );

        insert new List<Job_Opening__c>{
            expiredJo, activeJo
        };
    }

    @IsTest
    static void test_expiredOpeningIsClosed() {
        Test.startTest();
        Database.executeBatch(new CloseExpiredJobOpeningsBatch(), 200);
        Test.stopTest();

        Job_Opening__c expired = [
            SELECT Status__c
            FROM Job_Opening__c
            WHERE Job_Title__c = 'Expired Role'
            LIMIT 1
        ];
        System.Assert.areEqual('Closed', expired.Status__c,
            'Expired opening should be Closed');
    }

    @IsTest
    static void test_activeOpeningNotClosed() {
        Test.startTest();
        Database.executeBatch(new CloseExpiredJobOpeningsBatch(), 200);
        Test.stopTest();

        Job_Opening__c active = [
            SELECT Status__c
            FROM Job_Opening__c
            WHERE Job_Title__c = 'Active Role'
            LIMIT 1
        ];
        System.Assert.areEqual('Open', active.Status__c,
            'Active opening should remain Open');
    }

    @IsTest
    static void test_scheduler() {
        Test.startTest();
        String cronExp = '0 0 0 * * ?';
        System.schedule(
            'Test Close Expired Jobs',
            cronExp,
            new CloseExpiredJobOpeningsScheduler()
        );
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name =
                'Test Close Expired Jobs'
        ];
        System.Assert.areEqual(1, jobs.size(),
            'Scheduler should be registered');
    }

    @IsTest
    static void test_bulkBatch_200Records() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<Job_Opening__c> bulkOpenings =
            new List<Job_Opening__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkOpenings.add(new Job_Opening__c(
                Job_Title__c = 'Bulk Role ' + i,
                Account__c = acc.Id,
                Status__c = 'Open',
                Employment_Type__c = 'Full-Time',
                Department__c = 'Engineering',
                Openings_Count__c = 1,
                Application_Deadline__c =
                    Date.today().addDays(-1)
            ));
        }
        insert bulkOpenings;

        Test.startTest();
        Database.executeBatch(new CloseExpiredJobOpeningsBatch(), 200);
        Test.stopTest();

        Integer closedCount = [
            SELECT COUNT()
            FROM Job_Opening__c
            WHERE Status__c = 'Closed'
        ];
        System.Assert.isTrue(closedCount >= 200,
            'All 200 bulk openings should be closed');
    }
}
