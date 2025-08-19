// Test script to verify LocationLoader timezone fix
// This script tests the loadLocationAvailability method to ensure it doesn't return
// availability that overlaps with already scheduled sessions

// First, let's check what events exist
System.debug('=== Testing LocationLoader Timezone Fix ===');

// Query for events with timezone information
List<Event__c> events = [
    SELECT Id, Name, Event_Start_Date__c, Event_End_Date__c, Event_Timezone__c
    FROM Event__c 
    WHERE Event_Start_Date__c != null 
    AND Event_End_Date__c != null
    LIMIT 5
];

System.debug('Found ' + events.size() + ' events:');
for (Event__c event : events) {
    System.debug('Event: ' + event.Name + ' (ID: ' + event.Id + ')');
    System.debug('  Start: ' + event.Event_Start_Date__c + ' (Timezone: ' + event.Event_Timezone__c + ')');
    System.debug('  End: ' + event.Event_End_Date__c);
}

if (events.isEmpty()) {
    System.debug('No events found. Please create an event first.');
    return;
}

// Test the LocationLoader with the first event
Id testEventId = events[0].Id;
System.debug('\n=== Testing LocationLoader with Event: ' + events[0].Name + ' ===');

// Call the LocationLoader
List<String> availabilityResults = LocationLoader.loadLocationAvailability(new List<Id>{testEventId});

System.debug('LocationLoader returned ' + availabilityResults.size() + ' result(s)');

if (!availabilityResults.isEmpty()) {
    String resultJson = availabilityResults[0];
    System.debug('Result JSON: ' + resultJson);
    
    // Parse the JSON to check for overlapping availability
    try {
        List<LocationLoader.LocationWithAvailability> locations = 
            (List<LocationLoader.LocationWithAvailability>) JSON.deserialize(
                resultJson, List<LocationLoader.LocationWithAvailability>.class);
        
        System.debug('Parsed ' + locations.size() + ' locations');
        
        for (LocationLoader.LocationWithAvailability location : locations) {
            System.debug('\nLocation: ' + location.locationName + ' (ID: ' + location.locationId + ')');
            System.debug('Room Size: ' + location.roomSize + ', Capacity: ' + location.roomCapacity);
            System.debug('Availability Periods: ' + location.availabilityPeriods.size());
            
            for (LocationLoader.LocationAvailability period : location.availabilityPeriods) {
                System.debug('  Period: ' + period.availabilityStart + ' to ' + period.availabilityEnd + 
                           ' (' + period.durationMinutes + ' minutes)');
            }
        }
        
        // Now let's check for any scheduled sessions that might overlap
        System.debug('\n=== Checking for Scheduled Sessions ===');
        List<Session_Slot__c> scheduledSlots = [
            SELECT Id, Session_Location__c, Date__c, Start_Time__c, End_Time__c,
                   Session_Location__r.Name, Session_Location__r.Event__c
            FROM Session_Slot__c 
            WHERE Session_Location__r.Event__c = :testEventId
            ORDER BY Date__c, Start_Time__c
        ];
        
        System.debug('Found ' + scheduledSlots.size() + ' scheduled slots');
        for (Session_Slot__c slot : scheduledSlots) {
            System.debug('Scheduled: ' + slot.Date__c + ' ' + slot.Start_Time__c + ' to ' + slot.End_Time__c + 
                       ' at ' + slot.Session_Location__r.Name);
        }
        
        // Check for potential overlaps
        System.debug('\n=== Checking for Potential Overlaps ===');
        for (LocationLoader.LocationWithAvailability location : locations) {
            for (LocationLoader.LocationAvailability period : location.availabilityPeriods) {
                for (Session_Slot__c slot : scheduledSlots) {
                    if (slot.Session_Location__c == location.locationId) {
                        // Create datetime objects directly in the event's timezone
                        Datetime slotStart = Datetime.newInstance(slot.Date__c, slot.Start_Time__c);
                        Datetime slotEnd = Datetime.newInstance(slot.Date__c, slot.End_Time__c);
                        
                        // Check for overlap
                        if ((period.availabilityStart < slotEnd && period.availabilityEnd > slotStart)) {
                            System.debug('*** OVERLAP DETECTED ***');
                            System.debug('  Availability: ' + period.availabilityStart + ' to ' + period.availabilityEnd);
                            System.debug('  Scheduled: ' + slotStart + ' to ' + slotEnd);
                            System.debug('  Location: ' + location.locationName);
                        }
                    }
                }
            }
        }
        
    } catch (Exception e) {
        System.debug('Error parsing JSON result: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
} else {
    System.debug('No availability results returned');
}

System.debug('\n=== Test Complete ==='); 