public class SendEmailBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Map<Id, Id> contactIdToUserIdMap;
    
    public SendEmailBatch() {
        contactIdToUserIdMap = new Map<Id, Id>();
    }
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        // Query all community users where ContactId is not null
        for (User user : [SELECT Id, ContactId FROM User WHERE ContactId != null]) {
            contactIdToUserIdMap.put(user.ContactId, user.Id);
        }
        return Database.getQueryLocator([SELECT Id, Name, Type__c, Notification_Status__c,Generation_Date__c, Customer_Notified_At__c, Account__c, Contact__c, Contact__r.Email, Product__c, CreatedDate, 
                                         (SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId, ContentDocument.LatestPublishedVersion.Title, ContentDocument.LatestPublishedVersion.FileExtension, ContentDocument.LatestPublishedVersion.VersionData FROM ContentDocumentLinks)
                                         FROM Document__c WHERE Notification_Status__c = 'New']);
    }
    
    public void execute(Database.BatchableContext context, List<Document__c> documentList) {
        
        Map<Id, Map<String, List<Document__c>>> contactDocumentMap = new Map<Id, Map<String, List<Document__c>>>();
        List<Document__c> documentListToUpdate = new List<Document__c>();
        
        // Group documents by customer and document type
        for (Document__c doc : documentList) {
            String docType = doc.Type__c;
            Id contactId = doc.Contact__c;
            
            if (!contactDocumentMap.containsKey(contactId)) {
                contactDocumentMap.put(contactId, new Map<String, List<Document__c>>());
            }
            
            Map<String, List<Document__c>> documentTypeMap = contactDocumentMap.get(contactId);
            if (!documentTypeMap.containsKey(docType)) {
                documentTypeMap.put(docType, new List<Document__c>());
            }
            
            List<Document__c> documents = documentTypeMap.get(docType);
            documents.add(doc);
        }
        
        // List of email instances
        List<Messaging.SingleEmailMessage> sendEmailList = new List<Messaging.SingleEmailMessage>();
        
        // Send emails for each document type to respective contacts
        for (Id contactId : contactDocumentMap.keySet()) {
            Map<String, List<Document__c>> documentTypeMap = contactDocumentMap.get(contactId);
            
            for (String docType : documentTypeMap.keySet()) {
                List<Document__c> documents = documentTypeMap.get(docType);               
                String recipientId = (!contactIdToUserIdMap.isEmpty() && contactIdToUserIdMap.containsKey(contactId)) ? contactIdToUserIdMap.get(contactId) : contactId;
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();    
                email.setTargetObjectId(recipientId);
                //email.setSaveAsActivity(true);
                email.setSubject('New ' + docType + ' Document(s) Available: ');
                
                // Compose email content with document list
                String listOfDocuments = '';
                for (Integer i = 0; i < documents.size(); i++) {
                    listOfDocuments += (i+1) + '. ' + documents[i].Name + '\n';
                }
                email.setPlainTextBody('New ' + docType + ' Document(s) are available and attached in the mail. PFB list of Documents:' + '\n' + listOfDocuments);
                
                List<Messaging.EmailFileAttachment> emailAttachments = new List<Messaging.EmailFileAttachment>(); // List to store attachments
                
                // Attach documents to the email
                for (Document__c document : documents) {
                    for (ContentDocumentLink conDocLink : document.ContentDocumentLinks) {
                        Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
                        Blob fileData = conDocLink.ContentDocument.LatestPublishedVersion.VersionData;
                        emailAttachment.setFileName(conDocLink.ContentDocument.LatestPublishedVersion.Title + '.' + conDocLink.ContentDocument.LatestPublishedVersion.FileExtension);
                        emailAttachment.setBody(fileData);
                        emailAttachments.add(emailAttachment); // Add attachment to the list
                    }
                    
                    // Update document status and timestamp
                    document.Notification_Status__c = 'Customer Notified';
                    document.Customer_Notified_At__c = System.Now();
                    
                    // Add document to the update list
                    documentListToUpdate.add(document);
                }
                
                // Set all attachments on the email
                email.setFileAttachments(emailAttachments);
                
                // Add the email instance in the list
                sendEmailList.add(email);
            }
        }
        
        // Send all emails in one call
        if (!sendEmailList.isEmpty()) {
            System.debug('sendEmailList.size()'+sendEmailList.size());
            System.debug('sendEmailList'+sendEmailList);
            //Messaging.sendEmail(sendEmailList);            
        }
        
        // Update documents in the database together from list
        if (!documentListToUpdate.isEmpty()) {
            Database.update(documentListToUpdate, false);
        }
        
    }
    
    public void finish(Database.BatchableContext context) {
        // Perform any cleanup or post-processing tasks if needed
    }
}