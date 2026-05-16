public without sharing class RecruitmentPublicController {

    @AuraEnabled(cacheable=true)
    public static List<Job_Opening__c> getOpenJobOpenings() {
        try {
            return Database.query(buildOpenJobsQuery());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id submitApplication(
        String jobOpeningId,
        String firstName,
        String lastName,
        String email,
        String phone,
        String linkedInProfile,
        String currentEmployer,
        String currentJobTitle,
        Decimal yearsOfExperience,
        Decimal expectedSalary,
        Decimal noticePeriodDays,
        String coverLetter,
        String source
    ) {
        if (String.isBlank(jobOpeningId)
            || String.isBlank(firstName)
            || String.isBlank(lastName)
            || String.isBlank(email)
            || expectedSalary == null) {
            throw new AuraHandledException('Required fields are missing.');
        }

        try {
            Contact contact = getOrCreateContact(
                firstName,
                lastName,
                email,
                phone,
                linkedInProfile,
                currentEmployer,
                currentJobTitle
            );

            Job_Application__c application = new Job_Application__c();
            setIfFieldExists(application, 'Contact__c', contact.Id);
            setIfFieldExists(application, 'Candidate__c', contact.Id);
            application.put('Job_Opening__c', jobOpeningId);
            setIfFieldExists(application, 'Applied_Date__c', Date.today());
            setIfFieldExists(application, 'Application_Stage__c', 'New');
            setIfFieldExists(application, 'Years_of_Experience__c', yearsOfExperience);
            setIfFieldExists(application, 'Expected_Salary__c', expectedSalary);
            setIfFieldExists(application, 'Notice_Period_Days__c', noticePeriodDays);
            setIfFieldExists(application, 'Cover_Letter__c', coverLetter);
            setIfFieldExists(application, 'Source__c', 
                String.isNotBlank(source) ? source : 'Company Website');

            insert application;
            return application.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Contact getOrCreateContact(
        String firstName,
        String lastName,
        String email,
        String phone,
        String linkedInProfile,
        String currentEmployer,
        String currentJobTitle
    ) {
        List<Contact> existing = [
            SELECT Id
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        Contact contact = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Phone = phone
        );
        setIfFieldExists(contact, 'Type', 'Candidate');
        setIfFieldExists(contact, 'Contact_Type__c', 'Candidate');
        setIfFieldExists(contact, 'Candidate_Status__c', 'Active — Looking');
        setIfFieldExists(contact, 'LinkedIn_Profile__c', linkedInProfile);
        setIfFieldExists(contact, 'Current_Employer__c', currentEmployer);
        setIfFieldExists(contact, 'Current_Job_Title__c', currentJobTitle);
        insert contact;
        return contact;
    }

    private static void setIfFieldExists(
        SObject record,
        String fieldName,
        Object value
    ) {
        if (value == null) return;

        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldName)) return;

        Schema.DescribeFieldResult describeResult =
            fieldMap.get(fieldName).getDescribe();
        if (!describeResult.isCreateable()) return;

        record.put(fieldName, value);
    }

    private static String buildOpenJobsQuery() {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Job_Opening__c.fields.getMap();
        List<String> selectFields = new List<String>{'Id', 'Name'};

        if (fieldMap.containsKey('Job_Title__c')) {
            selectFields.add('Job_Title__c');
        }
        if (fieldMap.containsKey('Location__c')) {
            selectFields.add('Location__c');
        }
        if (fieldMap.containsKey('Department__c')) {
            selectFields.add('Department__c');
        }

        String soql = 'SELECT ' + String.join(selectFields, ', ')
            + ' FROM Job_Opening__c';

        if (fieldMap.containsKey('Status__c')) {
            soql += ' WHERE Status__c = \'Open\'';
        }

        soql += ' ORDER BY CreatedDate DESC LIMIT 200';
        return soql;
    }
}
