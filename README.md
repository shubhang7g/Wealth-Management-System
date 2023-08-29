**Steps to run the code:-**

1. Deploy the "Document__c" custom object, 'SendEmailBatch', 'SendEmailBatchTest', 'SendEmailBatchScheduler' from the repository to the Salesforce org.
2. Navigate to Developer Console in your Salesforce instance and click the Debug Menu. From there you will click the Open Execute Anonymous option and execute the below lines to run the batch immediately:<br/>
`SendEmailBatch sendEmail = new SendEmailBatch();` <br/>
`Database.executeBatch(sendEmail);`
4. For Scheduling batch class thrice a day run the below lines:<br/>
`String cronExpression = '0 0 9,17,1 * * ?’; // Starting from 9 AM, 5 PM and 1 AM`<br/>
`SendEmailBatchScheduler sendEmailBatchScheduler = new SendEmailBatchScheduler();`<br/>
`System.schedule('Send Email Batch Job', cronExpression, sendEmailBatchScheduler);`

Thank you!



