/**
 * @description Loads sessions that don't have related Session_Slot records (unscheduled sessions)
 *              for use in the conference scheduling system.
 * @Version 1.0
 */
public with sharing class UnscheduledSessionLoader {
    
    /**
     * @description Loads unscheduled sessions (sessions without related Session_Slot records)
     *              with an optional limit on the number of results returned.
     * @param sessionLimit The maximum number of sessions to return (0 = no limit)
     * @return List<String> List of JSON strings containing Session wrapper objects for unscheduled sessions
     */
    @InvocableMethod(
        label='Load Unscheduled Sessions'
        description='Loads sessions that don\'t have related Session_Slot records (unscheduled sessions)'
        category='Conference Scheduling'
    )
    public static List<String> loadUnscheduledSessions(List<Integer> sessionLimit) {
        // Extract the limit value from the list (Flow Builder will pass a single value)
        Integer limitValue = 0; // Default to no limit
        if (sessionLimit != null && !sessionLimit.isEmpty()) {
            limitValue = sessionLimit[0];
        }
        
        // Validate input parameter
        if (limitValue == null || limitValue < 0) {
            limitValue = 0; // 0 means no limit
        }
        
        // try {
            // Build the SOQL query to find sessions without related Session_Slot records
            // Include Session_Speaker__c records as a subquery for efficiency
            String query = 'SELECT Id, Name, Event__c, Session_Abstract__c, Format__c, Focus__c, ' +
                          'Requested_Room_Size__c, Session_Length_Minutes__c, Scheduled__c, Session_Slot_Count__c, ' +
                          'Session_Scheduled_Placeholder__c, ' +
                          '(SELECT Id, Session__c, Speaker__c, Speaker__r.FirstName, Speaker__r.LastName, ' +
                          'Speaker__r.Email, Speaker__r.Title, Speaker__r.Account.Name ' +
                          'FROM Session_Speakers__r ' +
                          'ORDER BY Speaker__r.LastName, Speaker__r.FirstName) ' +
                          'FROM Session__c ' +
                          'WHERE Id NOT IN (SELECT Session__c FROM Session_Slot__c) ' +
                          'ORDER BY Name';
            
            // Add limit if specified
            if (limitValue > 0) {
                query += ' LIMIT ' + limitValue;
            }
            
            // Execute the query
            List<Session__c> unscheduledSessions = Database.query(query);
            
            // Convert to Session wrapper objects
            List<Session> sessions = new List<Session>();
            
            for (Session__c sessionRecord : unscheduledSessions) {
                Session session = new Session(sessionRecord);
                sessions.add(session);
            }

            // Match the LocationLoader pattern exactly: create a list with a single JSON string
            List<String> sessionJsonStrings = new List<String>();
            sessionJsonStrings.add(JSON.serialize(sessions));
            return sessionJsonStrings;
            
        // } catch (Exception e) {
        //     // Log the error and return empty list
        //     System.debug(LoggingLevel.ERROR, 'Error loading unscheduled sessions: ' + e.getMessage());
        //     System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        //     return new List<String>();
        // }
    }
    
    /**
     * @description Default constructor
     */
    public UnscheduledSessionLoader() {
        // Default constructor
    }
}