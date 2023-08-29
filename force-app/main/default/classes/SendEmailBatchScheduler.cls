public class SendEmailBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Start the batch job
        SendEmailBatch sendEmail = new SendEmailBatch();
        Database.executeBatch(sendEmail);
    }
}