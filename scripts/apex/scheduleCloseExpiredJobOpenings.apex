String jobName = 'Close Expired Job Openings (Nightly)';
String cronExp = '0 0 0 * * ?';

List<CronTrigger> existingJobs = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
];
for (CronTrigger ct : existingJobs) {
    System.abortJob(ct.Id);
}

System.schedule(jobName, cronExp, new CloseExpiredJobOpeningsScheduler());
