@isTest
private class ClientPortalControllerTest {

    @testSetup
    static void setup() {

        // Step 1 - assign role to current user
        // must be in separate transaction from non-setup objects
        UserRole role = [
            SELECT Id FROM UserRole
            WHERE PortalType = 'None'
            LIMIT 1
        ];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            User me = new User(
                Id = UserInfo.getUserId(),
                UserRoleId = role.Id
            );
            update me;
        }

        // Step 2 - insert non-setup objects (Account, Job Opening)
        Account acctA = new Account(
            Name = 'Client A',
            Account_Status__c = 'Active',
            Primary_Industry_Sector__c = 'Information Technology',
            Phone = '415-555-0101',
            Website = 'https://example.com'
        );
        Account acctB = new Account(
            Name = 'Client B',
            Account_Status__c = 'Active',
            Primary_Industry_Sector__c = 'Information Technology',
            Phone = '415-555-0101',
            Website = 'https://example.com'
        );
        insert new List<Account>{ acctA, acctB };

        insert new List<Job_Opening__c>{
            new Job_Opening__c(
                Job_Title__c = 'Client A Role 1',
                Account__c = acctA.Id,
                Status__c = 'Open',
                Employment_Type__c = 'Full-Time',
                Department__c = 'Engineering',
                Openings_Count__c = 1,
                Application_Deadline__c = Date.today().addDays(14)
            ),
            new Job_Opening__c(
                Job_Title__c = 'Client A Role 2',
                Account__c = acctA.Id,
                Status__c = 'Open',
                Employment_Type__c = 'Full-Time',
                Department__c = 'Engineering',
                Openings_Count__c = 2,
                Application_Deadline__c = Date.today().addDays(30)
            ),
            new Job_Opening__c(
                Job_Title__c = 'Client B Role 1',
                Account__c = acctB.Id,
                Status__c = 'Open',
                Employment_Type__c = 'Full-Time',
                Department__c = 'Engineering',
                Openings_Count__c = 1,
                Application_Deadline__c = Date.today().addDays(7)
            )
        };

        // Step 3 - insert Users (setup objects)
        // separate from Account insert above
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String ts = String.valueOf(DateTime.now().getTime());

        User clientUser = new User(
            Username = 'clientuser.' + ts + '@test.com',
            Email = 'clientuser@test.com',
            LastName = 'ClientUser',
            Alias = 'cuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            CompanyName = 'Client A'
        );

        User standardUser = new User(
            Username = 'standarduser.' + ts + '@test.com',
            Email = 'standarduser@test.com',
            LastName = 'StandardUser',
            Alias = 'suser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            CompanyName = ''
        );

        insert new List<User>{ clientUser, standardUser };
    }

    // ── helpers ──────────────────────────────────────────────

    private static User getClientUser() {
        return [
            SELECT Id, CompanyName
            FROM User
            WHERE Alias = 'cuser'
            LIMIT 1
        ];
    }

    private static User getStandardUser() {
        return [
            SELECT Id
            FROM User
            WHERE Alias = 'suser'
            LIMIT 1
        ];
    }

    // ── Tests ─────────────────────────────────────────────────

    @isTest
    static void test_getMyJobOpenings_filtersByCompanyName() {
        User clientUser = getClientUser();

        System.runAs(clientUser) {
            Test.startTest();
            List<Job_Opening__c> results =
                ClientPortalController.getMyJobOpenings();
            Test.stopTest();

            Assert.areEqual(2, results.size(),
                'Should return 2 openings for Client A');

            Set<String> titles = new Set<String>();
            for(Job_Opening__c jo : results) {
                titles.add(jo.Job_Title__c);
            }
            Assert.isTrue(titles.contains('Client A Role 1'),
                'Client A Role 1 should be included');
            Assert.isTrue(titles.contains('Client A Role 2'),
                'Client A Role 2 should be included');
            Assert.isFalse(titles.contains('Client B Role 1'),
                'Client B Role 1 should be excluded');
        }
    }

    @isTest
    static void test_getMyJobOpenings_noCompany_returnsEmpty() {
        User standardUser = getStandardUser();

        System.runAs(standardUser) {
            Test.startTest();
            List<Job_Opening__c> results =
                ClientPortalController.getMyJobOpenings();
            Test.stopTest();

            Assert.areEqual(0, results.size(),
                'User with no company should see no openings');
        }
    }

    @isTest
    static void test_createJobOpening_createsRecord() {
        User clientUser = getClientUser();
        User standardUser = getStandardUser();
        Date deadline = Date.today().addDays(21);

        System.runAs(clientUser) {
            Test.startTest();
            Id joId = ClientPortalController.createJobOpening(
                'API Engineer',
                'Engineering',
                'Remote',
                'Full-Time',
                3,
                deadline,
                'Build and maintain APIs.',
                true,
                80000,
                120000,
                4.5,
                'Apex, LWC, REST',
                standardUser.Id
            );
            Test.stopTest();

            Job_Opening__c jo = [
                SELECT Job_Title__c, Department__c,
                       Location__c, Employment_Type__c,
                       Openings_Count__c, Application_Deadline__c,
                       Job_Description__c, Status__c,
                       Is_Remote__c, Min_Salary__c, Max_Salary__c,
                       Required_Experience_Years__c,
                       Required_Skills__c, Recruiter__c
                FROM Job_Opening__c
                WHERE Id = :joId
                LIMIT 1
            ];

            Assert.areEqual('API Engineer', jo.Job_Title__c,
                'Job title should match');
            Assert.areEqual('Engineering', jo.Department__c,
                'Department should match');
            Assert.areEqual('Remote', jo.Location__c,
                'Location should match');
            Assert.areEqual('Full-Time', jo.Employment_Type__c,
                'Employment type should match');
            Assert.areEqual(3, jo.Openings_Count__c,
                'Openings count should match');
            Assert.areEqual(deadline, jo.Application_Deadline__c,
                'Deadline should match');
            Assert.areEqual('Open', jo.Status__c,
                'Status should be Open');
            Assert.isTrue(jo.Is_Remote__c,
                'Is Remote should be true');
            Assert.areEqual(80000, jo.Min_Salary__c,
                'Min salary should match');
            Assert.areEqual(120000, jo.Max_Salary__c,
                'Max salary should match');
            Assert.areEqual(4.5, jo.Required_Experience_Years__c,
                'Required experience should match');
            Assert.areEqual('Apex, LWC, REST', jo.Required_Skills__c,
                'Required skills should match');
            Assert.areEqual(standardUser.Id, jo.Recruiter__c,
                'Recruiter should match');
        }
    }

    @isTest
    static void test_createJobOpening_noCompany_throwsError() {
        User standardUser = getStandardUser();

        System.runAs(standardUser) {
            Test.startTest();
            try {
                ClientPortalController.createJobOpening(
                    'No Account Role',
                    'Engineering',
                    'Remote',
                    'Full-Time',
                    1,
                    Date.today().addDays(7),
                    'Should fail.',
                    false,
                    null,
                    null,
                    null,
                    null,
                    null
                );
                Assert.fail(
                    'Expected AuraHandledException to be thrown');
            } catch(AuraHandledException e) {
                Assert.isTrue(
                    e.getMessage() != null,
                    'Exception message should not be null');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void test_createJobOpening_bulkCreation() {
        User clientUser = getClientUser();

        System.runAs(clientUser) {
            Test.startTest();
            List<Id> createdIds = new List<Id>();
            for(Integer i = 0; i < 5; i++) {
                createdIds.add(
                    ClientPortalController.createJobOpening(
                        'Role ' + i,
                        'Engineering',
                        'Remote',
                        'Full-Time',
                        1,
                        Date.today().addDays(30),
                        'Description ' + i,
                        false,
                        null,
                        null,
                        null,
                        null,
                        null
                    )
                );
            }
            Test.stopTest();

            List<Job_Opening__c> created = [
                SELECT Id FROM Job_Opening__c
                WHERE Id IN :createdIds
            ];
            Assert.areEqual(5, created.size(),
                '5 job openings should be created');
        }
    }
}