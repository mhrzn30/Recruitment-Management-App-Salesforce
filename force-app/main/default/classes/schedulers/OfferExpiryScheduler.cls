public with sharing class OfferExpiryScheduler
    implements Schedulable {

    public void execute(SchedulableContext context) {
        Database.executeBatch(new CloseExpiredOffersBatch(), 200);
        Database.executeBatch(new OfferExpiryReminderBatch(), 200);
    }
}
