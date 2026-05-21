public with sharing class ClientPortalController {

    private static final String DEMO_ACCOUNT_NAME = 'Mandapx';

    private static Id resolveUserAccountId() {
        User currentUser = [
            SELECT AccountId, CompanyName
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (currentUser.AccountId != null) {
            return currentUser.AccountId;
        }

        if (!String.isBlank(currentUser.CompanyName)) {
            List<Account> matches = [
                SELECT Id
                FROM Account
                WHERE Name = :currentUser.CompanyName
                LIMIT 1
            ];

            if (!matches.isEmpty()) {
                return matches[0].Id;
            }
        }

        // Demo fallback when no account is linked to the user.
        if (!String.isBlank(DEMO_ACCOUNT_NAME)) {
            List<Account> demoMatches = [
                SELECT Id
                FROM Account
                WHERE Name = :DEMO_ACCOUNT_NAME
                LIMIT 1
            ];

            if (!demoMatches.isEmpty()) {
                return demoMatches[0].Id;
            }
        }

        return null;
    }

    @AuraEnabled(cacheable=true)
    public static List<Job_Opening__c> getMyJobOpenings() {
        try {
            Id accountId = resolveUserAccountId();

            if (accountId == null) {
                return new List<Job_Opening__c>();
            }

            return [
                SELECT Id, Job_Title__c, Status__c,
                       Employment_Type__c, Department__c,
                       Location__c, Openings_Count__c,
                       Application_Deadline__c,
                       Total_Applications__c
                FROM Job_Opening__c
                WHERE Account__c = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createJobOpening(
        String jobTitle,
        String department,
        String location,
        String employmentType,
        Integer openingsCount,
        Date deadline,
        String jobDescription,
        Boolean isRemote,
        Decimal minSalary,
        Decimal maxSalary,
        Decimal requiredExperienceYears,
        String requiredSkills,
        Id recruiterId
    ) {
        try {
            Id accountId = resolveUserAccountId();

            if (accountId == null) {
                throw new AuraHandledException(
                    'No account linked to your user.'
                );
            }

            Job_Opening__c jo = new Job_Opening__c(
                Job_Title__c = jobTitle,
                Account__c = accountId,
                Department__c = department,
                Location__c = location,
                Employment_Type__c = employmentType,
                Openings_Count__c = openingsCount,
                Application_Deadline__c = deadline,
                Job_Description__c = jobDescription,
                Is_Remote__c = isRemote,
                Min_Salary__c = minSalary,
                Max_Salary__c = maxSalary,
                Required_Experience_Years__c = requiredExperienceYears,
                Required_Skills__c = requiredSkills,
                Recruiter__c = recruiterId,
                Status__c = 'Open'
            );
            insert jo;
            return jo.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<User> getRecruiters() {
        return [
            SELECT Id, Name, FirstName, LastName, Alias
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'Recruiter'
            ORDER BY Name
        ];
    }
}
