// Script to set default timezones for existing Event__c records
// Run this after deploying the Event_Timezone__c field

System.debug('Starting timezone update for existing events...');

try {
    // Query for events without timezone set
    List<Event__c> eventsToUpdate = [
        SELECT Id, Name, Event_Start_Date__c, Event_End_Date__c, Event_Timezone__c
        FROM Event__c 
        WHERE Event_Timezone__c = null
    ];
    
    System.debug('Found ' + eventsToUpdate.size() + ' events without timezone');
    
    if (eventsToUpdate.isEmpty()) {
        System.debug('All events already have timezones set.');
        return;
    }
    
    // Set default timezone based on organization timezone or use UTC
    String defaultTimezone = 'UTC';
    
    // Try to get organization timezone
    try {
        Organization org = [SELECT TimeZoneSidKey FROM Organization LIMIT 1];
        if (org.TimeZoneSidKey != null) {
            // Map Salesforce timezone keys to IANA timezone identifiers
            Map<String, String> timezoneMapping = new Map<String, String>{
                'America/New_York' => 'America/New_York',
                'America/Chicago' => 'America/Chicago',
                'America/Denver' => 'America/Denver',
                'America/Los_Angeles' => 'America/Los_Angeles',
                'America/Anchorage' => 'America/Anchorage',
                'Pacific/Honolulu' => 'Pacific/Honolulu',
                'Europe/London' => 'Europe/London',
                'Europe/Paris' => 'Europe/Paris',
                'Asia/Tokyo' => 'Asia/Tokyo',
                'Asia/Shanghai' => 'Asia/Shanghai',
                'Australia/Sydney' => 'Australia/Sydney'
            };
            
            if (timezoneMapping.containsKey(org.TimeZoneSidKey)) {
                defaultTimezone = timezoneMapping.get(org.TimeZoneSidKey);
                System.debug('Using organization timezone: ' + defaultTimezone);
            } else {
                System.debug('Organization timezone not in mapping, using UTC. Org timezone: ' + org.TimeZoneSidKey);
            }
        }
    } catch (Exception e) {
        System.debug('Could not retrieve organization timezone, using UTC: ' + e.getMessage());
    }
    
    // Update events with default timezone
    for (Event__c event : eventsToUpdate) {
        event.Event_Timezone__c = defaultTimezone;
        System.debug('Setting timezone for event ' + event.Name + ' to ' + defaultTimezone);
    }
    
    // Perform the update
    update eventsToUpdate;
    
    System.debug('Successfully updated ' + eventsToUpdate.size() + ' events with timezone: ' + defaultTimezone);
    
} catch (Exception e) {
    System.debug('Error updating event timezones: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
} 