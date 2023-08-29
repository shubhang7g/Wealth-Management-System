@isTest
public class SendEmailBatchTest {
    @testSetup
    static void setupTestData() {
        // Create test data
        
        List<Account> accList = new List<Account>();        
        Account testAccount1 = new Account(Name = 'Test Account 1');
        accList.add(testAccount1);
        Account testAccount2 = new Account(Name = 'Test Account 2');        
        accList.add(testAccount2);
        insert accList;
        
        List<Contact> conList = new List<Contact>();
        Contact testContact1 = new Contact(LastName = 'Test Contact 1', AccountId = testAccount1.Id, Email = 'testcontact1@example.com.invalid');
        conList.add(testContact1);       
        Contact testContact2 = new Contact(LastName = 'Test Contact 2', AccountId = testAccount2.Id, Email = 'testcontact2@example.com.invalid');
        conList.add(testContact2);
        insert conList;
        
        List<Document__c> documentsToInsert = new List<Document__c>();
        List<ContentDocumentLink> contentDocumentLinksToInsert = new List<ContentDocumentLink>();
        
        // Create 8 Document__c objects for 1st contact
        List<String> docTypes1 = new List<String>{'Report', 'Report', 'Transactional', 'Transactional', 'Legal', 'Legal', 'Contract', 'Contract'};
            for (Integer i = 0; i < 8; i++) {
                String docType = docTypes1[i];
                String contentTitle = docType + (i + 1);
                
                Document__c testDocument = new Document__c(
                    Name = 'Test Document ' + (i + 1), Type__c = docType,
                    Notification_Status__c = 'New', Contact__c = testContact1.Id
                );
                insert testDocument;
                
                ContentVersion testContentVersion = new ContentVersion(
                    Title = contentTitle, VersionData = Blob.valueOf('Test Content Data' + (i + 1)), PathOnClient = contentTitle + '.txt'
                );
                insert testContentVersion;
                
                ContentDocument testContentDocument = [
                    SELECT Id, Title, LatestPublishedVersionId 
                    FROM ContentDocument
                    WHERE LatestPublishedVersionId = :testContentVersion.Id
                ];
                
                ContentDocumentLink testContentDocumentLink = new ContentDocumentLink(
                    ContentDocumentId = testContentDocument.Id,
                    LinkedEntityId = testDocument.Id,
                    ShareType = 'V'
                );
                contentDocumentLinksToInsert.add(testContentDocumentLink);
            }
        
        // Create 4 Document__c objects for 2nd contact
        List<String> docTypes2 = new List<String>{'Report', 'Transactional', 'Legal', 'Contract'};
            for (Integer i = 0; i < 4; i++) {
                String docType = docTypes2[i];
                String contentTitle = docType;
                
                Document__c testDocument = new Document__c(
                    Name = 'Test File ' + (i + 1), Type__c = docType,
                    Notification_Status__c = 'New', Contact__c = testContact2.Id
                );
                insert testDocument;
                
                ContentVersion testContentVersion = new ContentVersion(
                    Title = contentTitle, VersionData = Blob.valueOf('Test Content Information' + (i + 1)), PathOnClient = contentTitle + '.txt'
                );
                insert testContentVersion;
                
                ContentDocument testContentDocument = [
                    SELECT Id, Title, LatestPublishedVersionId 
                    FROM ContentDocument
                    WHERE LatestPublishedVersionId = :testContentVersion.Id
                ];
                
                ContentDocumentLink testContentDocumentLink = new ContentDocumentLink(
                    ContentDocumentId = testContentDocument.Id,
                    LinkedEntityId = testDocument.Id,
                    ShareType = 'V'
                );
                contentDocumentLinksToInsert.add(testContentDocumentLink);
            }
        
        insert contentDocumentLinksToInsert;
        
        // Create user records
        List<User> userList = new List<User>();
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
       
        User adminUser = new User(
            FirstName = 'Admin', LastName = 'User', Alias = 'admin', Email = 'adminuser@example.com',
            Username = 'adminuser@example.com', ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'GMT', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        userList.add(adminUser);
        
        insert userList;
    }
    
    @isTest
    static void testSendEmailBatch() {    
        
        // Get admin user
        User adminUser = [Select Id, Profile.Name FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        String jobId;
        
        Test.startTest();       
        
        // Start the batch
        System.runAs(adminUser) {
            SendEmailBatch sendEmail = new SendEmailBatch();
            jobId = Database.executeBatch(sendEmail);        
        }
        
        Test.stopTest();
                
        // Query the job record
        AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        
        // Assert the status of the job
        System.assertEquals('Completed', job.Status);        
        
        List<Document__c> updatedDocuments = [SELECT Id, Notification_Status__c, Customer_Notified_At__c FROM Document__c];
        System.assertEquals(12, updatedDocuments.size());
        for (Document__c doc : updatedDocuments) {
            System.assertEquals('Customer Notified', doc.Notification_Status__c);
            System.assertNotEquals(null, doc.Customer_Notified_At__c);
        }
    }
}