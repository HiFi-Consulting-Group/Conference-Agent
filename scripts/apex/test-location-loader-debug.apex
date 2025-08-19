// Simple test script to debug LocationLoader behavior
// This will show us exactly what session slots are being loaded and how availability is calculated

System.debug('=== Testing LocationLoader Debug ===');

// Find an event to test with
List<Event__c> events = [
    SELECT Id, Name, Event_Start_Date__c, Event_End_Date__c, Event_Timezone__c
    FROM Event__c 
    WHERE Event_Start_Date__c != null 
    AND Event_End_Date__c != null
    LIMIT 1
];

if (events.isEmpty()) {
    System.debug('No events found. Please create an event first.');
    return;
}

Event__c testEvent = events[0];
System.debug('Testing with event: ' + testEvent.Name);
System.debug('Event timezone: ' + testEvent.Event_Timezone__c);

// Check what session slots exist for this event
List<Session_Slot__c> allSlots = [
    SELECT Id, Session_Location__c, Session_Location__r.Name, Date__c, Start_Time__c, End_Time__c
    FROM Session_Slot__c 
    WHERE Session_Location__r.Event__c = :testEvent.Id
    ORDER BY Date__c, Start_Time__c
];

System.debug('Total session slots for this event: ' + allSlots.size());

// Focus on the Alternate Lounge location mentioned in the user's example
System.debug('\n=== Focusing on Alternate Lounge Location ===');
List<Session_Slot__c> alternateLoungeSlots = [
    SELECT Id, Date__c, Start_Time__c, End_Time__c
    FROM Session_Slot__c 
    WHERE Session_Location__r.Event__c = :testEvent.Id
    AND Session_Location__r.Name = 'Alternate Lounge'
    ORDER BY Date__c, Start_Time__c
];

System.debug('Alternate Lounge slots: ' + alternateLoungeSlots.size());
for (Session_Slot__c slot : alternateLoungeSlots) {
    System.debug('Slot: ' + slot.Date__c + ' ' + slot.Start_Time__c + ' to ' + slot.End_Time__c);
    
    // Test the datetime creation logic using the correct GMT method
    Date slotDate = slot.Date__c;
    Time slotStartTime = slot.Start_Time__c;
    Time slotEndTime = slot.End_Time__c;
    
    // The Time fields represent UTC times, so use newInstanceGmt
    Datetime slotStartUTC = Datetime.newInstanceGmt(slotDate, slotStartTime);
    Datetime slotEndUTC = Datetime.newInstanceGmt(slotDate, slotEndTime);
    
    // Convert to Pacific Time for display
    String timezoneName = testEvent.Event_Timezone__c != null ? testEvent.Event_Timezone__c : 'America/Los_Angeles';
    TimeZone timezone = TimeZone.getTimeZone(timezoneName);
    Integer offsetStart = timezone.getOffset(slotStartUTC) / 1000;
    Integer offsetEnd = timezone.getOffset(slotEndUTC) / 1000;
    
    Datetime slotStartLocal = slotStartUTC.addSeconds(-offsetStart);
    Datetime slotEndLocal = slotEndUTC.addSeconds(-offsetEnd);
    
    System.debug('  UTC times: ' + slotStartUTC + ' to ' + slotEndUTC);
    System.debug('  Local times (PT): ' + slotStartLocal + ' to ' + slotEndLocal);
    System.debug('  Raw Time values: ' + slotStartTime + ' to ' + slotEndTime);
}

// Now call the LocationLoader to see what it returns
System.debug('\n=== Calling LocationLoader ===');
List<String> results = LocationLoader.loadLocationAvailability(new List<Id>{testEvent.Id});

System.debug('LocationLoader returned ' + results.size() + ' result(s)');
if (!results.isEmpty()) {
    System.debug('First result length: ' + results[0].length());
    
    // Look for Alternate Lounge availability specifically
    String result = results[0];
    if (result.contains('Alternate Lounge')) {
        System.debug('Found Alternate Lounge in results!');
        
        // Check if times are now showing in local time instead of UTC
        if (result.contains('"availabilityStart":"2025-09-01T07:00:00"') || 
            result.contains('"availabilityStart":"2025-09-01 07:00:00"')) {
            System.debug('✅ SUCCESS: Times are now showing in local time (7:00 AM PT)!');
            System.debug('Session slots at 2PM UTC (7AM PT) are correctly being converted to local time.');
        } else if (result.contains('"availabilityStart":"2025-09-01T14:00:00.000Z"')) {
            System.debug('❌ PROBLEM: Times are still showing in UTC (2PM UTC)!');
            System.debug('Need to convert session slot times to local time in the JSON output.');
        } else {
            System.debug('⚠️  UNKNOWN: Could not find expected time patterns in results.');
            System.debug('Checking for any availability on Sept 1st...');
        }
        
        // Extract just the Alternate Lounge section for easier reading
        Integer startIndex = result.indexOf('"locationName":"Alternate Lounge"');
        if (startIndex > 0) {
            Integer endIndex = result.indexOf('}', startIndex);
            if (endIndex > 0) {
                String alternateLoungeSection = result.substring(startIndex - 50, endIndex + 1);
                System.debug('Alternate Lounge section: ' + alternateLoungeSection);
            }
        }
    } else {
        System.debug('Alternate Lounge NOT found in results');
    }
}

System.debug('=== Test Complete ==='); 