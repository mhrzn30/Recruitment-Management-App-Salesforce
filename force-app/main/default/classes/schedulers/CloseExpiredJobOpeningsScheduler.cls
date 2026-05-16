public with sharing class CloseExpiredJobOpeningsScheduler
    implements Schedulable {

    public void execute(SchedulableContext context) {
        CloseExpiredJobOpeningsBatch batch =
            new CloseExpiredJobOpeningsBatch();
        Database.executeBatch(batch, 200);
    }
}
