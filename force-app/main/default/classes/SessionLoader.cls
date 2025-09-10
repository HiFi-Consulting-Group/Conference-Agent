public with sharing class SessionLoader {
    
    /**
     * Response structure for organizing sessions by slot status
     */
    public class SessionResponse {
        public List<Session> sessionsWithoutSlots;
        public List<Session> sessionsWithDraftSlots;
        public List<Session> sessionsWithFinalizedSlots;
        
        public SessionResponse() {
            this.sessionsWithoutSlots = new List<Session>();
            this.sessionsWithDraftSlots = new List<Session>();
            this.sessionsWithFinalizedSlots = new List<Session>();
        }
    }
    
    /**
     * Invocable method to load sessions and organize them by slot status
     * @param eventIds List of Event IDs to load sessions for
     * @return JSON string containing three lists of sessions organized by slot status
     */
    @InvocableMethod(label='Load Sessions Organized by Slot Status' 
                     description='Loads all sessions and organizes them by slot status (no slots, draft slots, finalized slots)')
    public static List<String> loadSessionsOrganizedBySlotStatus(List<Id> eventIds) {
        List<String> results = new List<String>();
        
        for (Id eventId : eventIds) {
            try {
                SessionResponse response = organizeSessionsBySlotStatus(eventId);
                results.add(JSON.serialize(response));
            } catch (Exception e) {
                // Log error and return empty response for this event
                System.debug(LoggingLevel.ERROR, 'Error loading sessions for event ' + eventId + ': ' + e.getMessage());
                SessionResponse emptyResponse = new SessionResponse();
                results.add(JSON.serialize(emptyResponse));
            }
        }
        
        return results;
    }
    
    /**
     * Organizes sessions by their slot status for a single event
     * @param eventId The ID of the Event to load sessions for
     * @return SessionResponse object with organized sessions
     */
    private static SessionResponse organizeSessionsBySlotStatus(Id eventId) {
        SessionResponse response = new SessionResponse();
        
        // Query for all sessions in the event with their session slots and speakers
        List<Session__c> sessionRecords = [
            SELECT Id, Name, Event__c, Focus__c, Format__c, Requested_Room_Size__c,
                   Scheduled__c, Session_Abstract__c, Session_Length_Minutes__c,
                   Session_Scheduled_Placeholder__c, Session_Slot_Count__c,
                   (SELECT Id, Name, Session_Location__c, Date__c, Start_Time__c, 
                           End_Time__c, Draft__c, Session__c
                    FROM Session_Slots__r 
                    ORDER BY Date__c, Start_Time__c),
                   (SELECT Id, Session__c, Speaker__c, Speaker__r.FirstName, Speaker__r.LastName, 
                           Speaker__r.Email, Speaker__r.Title, Speaker__r.Account.Name
                    FROM Session_Speakers__r)
            FROM Session__c 
            WHERE Event__c = :eventId
            ORDER BY Name
        ];
        
        // Convert to Session wrapper objects and organize by slot status
        for (Session__c sessionRecord : sessionRecords) {
            Session sessionWrapper = new Session(sessionRecord);
            
            if (sessionWrapper.sessionSlots.isEmpty()) {
                // No session slots
                response.sessionsWithoutSlots.add(sessionWrapper);
            } else {
                // Check if any slots are draft or finalized
                Boolean hasDraftSlots = false;
                Boolean hasFinalizedSlots = false;
                
                for (SessionSlot slot : sessionWrapper.sessionSlots) {
                    if (slot.isDraft) {
                        hasDraftSlots = true;
                    } else {
                        hasFinalizedSlots = true;
                    }
                }
                
                if (hasDraftSlots) {
                    response.sessionsWithDraftSlots.add(sessionWrapper);
                }
                if (hasFinalizedSlots) {
                    response.sessionsWithFinalizedSlots.add(sessionWrapper);
                }
            }
        }
        
        return response;
    }
    
    /**
     * Convenience method for single event ID (non-invocable)
     * @param eventId The ID of the Event to load sessions for
     * @return JSON string containing organized sessions
     */
    public static String loadSessionsForEvent(Id eventId) {
        SessionResponse response = organizeSessionsBySlotStatus(eventId);
        return JSON.serialize(response);
    }
    
    /**
     * Non-invocable method to get all sessions as a single list (for backward compatibility)
     * @param eventIds List of Event IDs to load sessions for
     * @return List of Session wrapper objects with their session slots
     */
    public static List<Session> loadSessionsWithSlots(List<Id> eventIds) {
        List<Session> allSessions = new List<Session>();
        
        try {
            // Query for all sessions in the events with their session slots and speakers
            List<Session__c> sessionRecords = [
                SELECT Id, Name, Event__c, Focus__c, Format__c, Requested_Room_Size__c,
                       Scheduled__c, Session_Abstract__c, Session_Length_Minutes__c,
                       Session_Scheduled_Placeholder__c, Session_Slot_Count__c,
                       (SELECT Id, Name, Session_Location__c, Date__c, Start_Time__c, 
                               End_Time__c, Draft__c 
                        FROM Session_Slots__r 
                        ORDER BY Date__c, Start_Time__c),
                       (SELECT Id, Session__c, Speaker__c, Speaker__r.FirstName, Speaker__r.LastName, 
                               Speaker__r.Email, Speaker__r.Title, Speaker__r.Account.Name
                        FROM Session_Speakers__r)
                FROM Session__c 
                WHERE Event__c IN :eventIds
                ORDER BY Name
            ];
            
            // Convert to Session wrapper objects
            allSessions = Session.fromSessionRecords(sessionRecords);
            
        } catch (Exception e) {
            // Log error and return empty list
            System.debug(LoggingLevel.ERROR, 'Error loading sessions for events ' + eventIds + ': ' + e.getMessage());
            allSessions = new List<Session>();
        }
        
        return allSessions;
    }
}