public with sharing class SessionScheduler {
    
    /**
     * Response wrapper for the invocable method
     */
    public class ScheduleSessionsResponse {
        @InvocableVariable(description='Number of session slots successfully upserted')
        public Integer upsertedCount;
        
        @InvocableVariable(description='Number of session slots that failed to upsert')
        public Integer failedCount;
        
        @InvocableVariable(description='Error messages for failed upserts')
        public List<String> errorMessages;
        
        @InvocableVariable(description='IDs of successfully upserted session slots')
        public List<Id> upsertedIds;
        
        public ScheduleSessionsResponse() {
            this.upsertedCount = 0;
            this.failedCount = 0;
            this.errorMessages = new List<String>();
            this.upsertedIds = new List<Id>();
        }
    }
    
    /**
     * Invocable method to schedule sessions by upserting SessionSlot records
     * @param sessionSlotsJsonList List of JSON strings, each containing array of SessionSlot wrapper objects
     * @return List of ScheduleSessionsResponse objects with upsert results
     */
    @InvocableMethod(label='Schedule Sessions' 
                     description='Accepts JSON string of SessionSlot wrapper objects and upserts them as Session_Slot__c records. May be used to create new session slots or modify existing ones.')
    public static List<ScheduleSessionsResponse> scheduleSessions(List<String> sessionSlotsJsonList) {
        List<ScheduleSessionsResponse> results = new List<ScheduleSessionsResponse>();
        
        for (String sessionSlotsJson : sessionSlotsJsonList) {
            ScheduleSessionsResponse response = new ScheduleSessionsResponse();
            
            try {
                // Deserialize the JSON string to get SessionSlot wrapper objects
                List<SessionSlot> sessionSlots = (List<SessionSlot>) JSON.deserialize(
                    sessionSlotsJson, List<SessionSlot>.class);
                
                if (sessionSlots != null && !sessionSlots.isEmpty()) {
                    // Convert wrapper objects to SObjects
                    List<Session_Slot__c> sessionSlotRecords = SessionSlot.toSessionSlotRecords(sessionSlots);
                    
                    // Upsert the records
                    Database.UpsertResult[] upsertResults = Database.upsert(sessionSlotRecords, false);
                    
                    // Process results
                    for (Integer i = 0; i < upsertResults.size(); i++) {
                        Database.UpsertResult result = upsertResults[i];
                        if (result.isSuccess()) {
                            response.upsertedCount++;
                            response.upsertedIds.add(result.getId());
                        } else {
                            response.failedCount++;
                            String errorMsg = 'Session Slot ' + (i + 1) + ': ';
                            for (Database.Error error : result.getErrors()) {
                                errorMsg += error.getMessage() + '; ';
                            }
                            response.errorMessages.add(errorMsg.trim());
                        }
                    }
                } else {
                    response.errorMessages.add('No session slots found in JSON input');
                }
                
            } catch (Exception e) {
                // Log error and add to response
                System.debug(LoggingLevel.ERROR, 'Error scheduling sessions: ' + e.getMessage());
                response.failedCount++;
                response.errorMessages.add('Processing error: ' + e.getMessage());
            }
            
            results.add(response);
        }
        
        return results;
    }
    
    /**
     * Non-invocable method to upsert SessionSlot wrapper objects directly
     * @param sessionSlots List of SessionSlot wrapper objects
     * @return ScheduleSessionsResponse object with upsert results
     */
    public static ScheduleSessionsResponse scheduleSessionsFromWrappers(List<SessionSlot> sessionSlots) {
        ScheduleSessionsResponse response = new ScheduleSessionsResponse();
        
        try {
            if (sessionSlots != null && !sessionSlots.isEmpty()) {
                // Convert wrapper objects to SObjects
                List<Session_Slot__c> sessionSlotRecords = SessionSlot.toSessionSlotRecords(sessionSlots);
                
                // Upsert the records
                Database.UpsertResult[] upsertResults = Database.upsert(sessionSlotRecords, false);
                
                // Process results
                for (Integer i = 0; i < upsertResults.size(); i++) {
                    Database.UpsertResult result = upsertResults[i];
                    if (result.isSuccess()) {
                        response.upsertedCount++;
                        response.upsertedIds.add(result.getId());
                    } else {
                        response.failedCount++;
                        String errorMsg = 'Session Slot ' + (i + 1) + ': ';
                        for (Database.Error error : result.getErrors()) {
                            errorMsg += error.getMessage() + '; ';
                        }
                        response.errorMessages.add(errorMsg.trim());
                    }
                }
            } else {
                response.errorMessages.add('No session slots provided');
            }
            
        } catch (Exception e) {
            // Log error and add to response
            System.debug(LoggingLevel.ERROR, 'Error scheduling sessions from wrappers: ' + e.getMessage());
            response.failedCount++;
            response.errorMessages.add('Processing error: ' + e.getMessage());
        }
        
        return response;
    }
}