public with sharing class EventLoader {
    
    /**
     * Invocable method to load an event by ID and return it as JSON
     * @param eventIds List of Event IDs to load
     * @return List of JSON strings containing Event wrapper objects
     */
    @InvocableMethod(label='Load Event by ID' 
                     description='Loads an Event record by ID and returns it as a JSON string')
    public static List<String> loadEventById(List<Id> eventIds) {
        List<String> results = new List<String>();
        
        try {
            // Query for the events
            List<Event__c> eventRecords = [
                SELECT Id, Name, Event_Start_Date__c, Event_End_Date__c
                FROM Event__c 
                WHERE Id IN :eventIds
            ];
            
            // Convert to Event wrapper objects and serialize to JSON
            for (Event__c eventRecord : eventRecords) {
                Event eventWrapper = new Event(eventRecord);
                results.add(JSON.serialize(eventWrapper));
            }
            
        } catch (Exception e) {
            // Log error and return empty result
            System.debug(LoggingLevel.ERROR, 'Error loading events: ' + e.getMessage());
            results.add('{}');
        }
        
        return results;
    }
    
    /**
     * Convenience method for single event ID (non-invocable)
     * @param eventId The ID of the Event to load
     * @return JSON string containing the Event wrapper object
     */
    public static String loadEventById(Id eventId) {
        List<String> results = loadEventById(new List<Id>{eventId});
        return results.isEmpty() ? '{}' : results[0];
    }
} 