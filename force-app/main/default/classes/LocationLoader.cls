/**
 * @description Loads session location availability by analyzing existing session slots
 *              and calculating available time periods within event constraints.
 * @Version 1.0
 */
public with sharing class LocationLoader {
    
    /**
     * @description Inner class to represent location availability
     */
    public class LocationAvailability {
        public Id locationId;
        public String locationName;
        public Id eventId;
        public Decimal roomCapacity;
        public String roomSize;
        public Date availabilityDate;
        public String availabilityStartLocal;  // Store as local time string
        public String availabilityEndLocal;    // Store as local time string
        public Integer durationMinutes;
        public String eventTimezone;  // Store timezone for reference
        
        /**
         * @description Constructor with parameters
         */
        public LocationAvailability(Id locationId, String locationName, Id eventId, 
                                   Decimal roomCapacity, String roomSize, 
                                   Date availabilityDate, Datetime availabilityStart, 
                                   Datetime availabilityEnd, String eventTimezone) {
            this.locationId = locationId;
            this.locationName = locationName;
            this.eventId = eventId;
            this.roomCapacity = roomCapacity != null ? roomCapacity : 0;
            this.roomSize = roomSize != null ? roomSize : '';
            this.availabilityDate = availabilityDate;
            this.eventTimezone = eventTimezone;
            
            // Convert UTC times to local time strings immediately
            if (availabilityStart != null && availabilityEnd != null && eventTimezone != null) {
                TimeZone timezone = TimeZone.getTimeZone(eventTimezone);
                Integer timezoneOffsetSeconds = timezone.getOffset(availabilityStart) / 1000;
                
                // Keep times in UTC and format with Z suffix
                this.availabilityStartLocal = availabilityStart.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS') + 'Z';
                this.availabilityEndLocal = availabilityEnd.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS') + 'Z';
            } else {
                // Fallback to UTC if no timezone info - format as UTC with Z suffix
                this.availabilityStartLocal = availabilityStart != null ? availabilityStart.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS') + 'Z' : null;
                this.availabilityEndLocal = availabilityEnd != null ? availabilityEnd.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS') + 'Z' : null;
            }
            
            // Calculate duration in minutes
            if (availabilityStart != null && availabilityEnd != null) {
                Long durationMillis = availabilityEnd.getTime() - availabilityStart.getTime();
                this.durationMinutes = (Integer)(durationMillis / (1000 * 60));
            } else {
                this.durationMinutes = 0;
            }
        }
    }
    
    /**
     * @description Subclass representing a location with its availability periods
     */
    public class LocationWithAvailability {
        @InvocableVariable(
            description='Session Location Record Id'
        )
        public Id locationId;
        
        @InvocableVariable(
            description='Session Location Name'
        )
        public String locationName;
        
        @InvocableVariable(
            description='Event this location belongs to'
        )
        public Id eventId;
        
        @InvocableVariable(
            description='Room Capacity'
        )
        public Decimal roomCapacity;
        
        @InvocableVariable(
            description='Room Size Category'
        )
        public String roomSize;
        
        @InvocableVariable(
            description='List of available time periods for this location'
        )
        public List<LocationAvailability> availabilityPeriods;
        
        /**
         * @description Constructor
         */
        public LocationWithAvailability() {
            this.locationId = null;
            this.locationName = '';
            this.eventId = null;
            this.roomCapacity = 0;
            this.roomSize = '';
            this.availabilityPeriods = new List<LocationAvailability>();
        }
        
        /**
         * @description Constructor with parameters
         */
        public LocationWithAvailability(Id locationId, String locationName, Id eventId, 
                                       Decimal roomCapacity, String roomSize) {
            this.locationId = locationId;
            this.locationName = locationName;
            this.eventId = eventId;
            this.roomCapacity = roomCapacity != null ? roomCapacity : 0;
            this.roomSize = roomSize != null ? roomSize : '';
            this.availabilityPeriods = new List<LocationAvailability>();
        }
    }
    
    /**
     * @description Loads availability for all session locations within an event
     * @param eventIds List of Event IDs to load availability for
     * @return List<String> List of JSON strings containing location availability periods
     */
    @InvocableMethod(
        label='Load Location Availability'
        description='Loads session location availability by analyzing existing session slots and calculating available time periods'
        category='Conference Scheduling'
    )
    public static List<String> loadLocationAvailability(List<Id> eventIds) {
        List<LocationWithAvailability> locationsWithAvailability = new List<LocationWithAvailability>();
        
        if (eventIds == null || eventIds.isEmpty()) {
            return new List<String>();
        }
        
        // try {
            // Load events with their start/end dates and timezone
            Map<Id, Event__c> eventsMap = new Map<Id, Event__c>([
                SELECT Id, Event_Start_Date__c, Event_End_Date__c, Event_Timezone__c
                FROM Event__c 
                WHERE Id IN :eventIds
                AND Event_Start_Date__c != null 
                AND Event_End_Date__c != null
            ]);
            
            if (eventsMap.isEmpty()) {
                return new List<String>();
            }
            
            // Load all session locations for these events
            List<Session_Location__c> locations = [
                SELECT Id, Name, Event__c, Room_Capacity__c, Room_Size__c
                FROM Session_Location__c 
                WHERE Event__c IN :eventIds
                ORDER BY Name
            ];
            
            // Load all session slots for these locations
            Set<Id> locationIds = new Map<Id, Session_Location__c>(locations).keySet();
            List<Session_Slot__c> sessionSlots = [
                SELECT Id, Session_Location__c, Date__c, Start_Time__c, End_Time__c
                FROM Session_Slot__c 
                WHERE Session_Location__c IN :locationIds
                ORDER BY Date__c, Start_Time__c
            ];
            
            System.debug('=== Loaded Session Slots ===');
            System.debug('Total session slots found: ' + sessionSlots.size());
            for (Session_Slot__c slot : sessionSlots) {
                System.debug('Slot: ID=' + slot.Id + ', Location=' + slot.Session_Location__c + 
                           ', Date=' + slot.Date__c + ', Time=' + slot.Start_Time__c + '-' + slot.End_Time__c);
            }
            
            // Group session slots by location and date
            Map<String, List<Session_Slot__c>> slotsByLocationAndDate = new Map<String, List<Session_Slot__c>>();
            for (Session_Slot__c slot : sessionSlots) {
                String key = slot.Session_Location__c + '_' + slot.Date__c;
                if (!slotsByLocationAndDate.containsKey(key)) {
                    slotsByLocationAndDate.put(key, new List<Session_Slot__c>());
                }
                slotsByLocationAndDate.get(key).add(slot);
            }
            
            System.debug('=== Grouped Session Slots ===');
            for (String key : slotsByLocationAndDate.keySet()) {
                List<Session_Slot__c> slots = slotsByLocationAndDate.get(key);
                System.debug('Key: ' + key + ' has ' + slots.size() + ' slots');
                for (Session_Slot__c slot : slots) {
                    System.debug('  Slot: ' + slot.Start_Time__c + ' to ' + slot.End_Time__c);
                }
            }
            
            // Process each location
            for (Session_Location__c location : locations) {
                Event__c event = eventsMap.get(location.Event__c);
                if (event == null) continue;
                
                // Create location with availability object
                LocationWithAvailability locationWithAvailability = new LocationWithAvailability(
                    location.Id, location.Name, location.Event__c,
                    location.Room_Capacity__c, location.Room_Size__c
                );
                
                // Generate availability for each day of the event
                Date currentDate = event.Event_Start_Date__c.date();
                Date endDate = event.Event_End_Date__c.date();
                
                while (currentDate <= endDate) {
                    // Skip weekends (optional - can be made configurable)
                    // if (currentDate.toStartOfWeek().addDays(6) == currentDate || 
                    //     currentDate.toStartOfWeek() == currentDate) {
                    //     currentDate = currentDate.addDays(1);
                    //     continue;
                    // }
                    
                    // Get existing slots for this location and date
                    String key = location.Id + '_' + currentDate;
                    List<Session_Slot__c> existingSlots = slotsByLocationAndDate.containsKey(key) ? 
                        slotsByLocationAndDate.get(key) : new List<Session_Slot__c>();
                    
                    System.debug('Processing location: ' + location.Name + ' for date: ' + currentDate);
                    System.debug('Key: ' + key + ' has ' + existingSlots.size() + ' existing slots');
                    for (Session_Slot__c slot : existingSlots) {
                        System.debug('  Existing slot: ' + slot.Start_Time__c + ' to ' + slot.End_Time__c);
                    }
                    
                    // Calculate available time slots for this day
                    List<LocationAvailability> dayAvailability = calculateDayAvailability(
                        location, event, currentDate, existingSlots
                    );
                    
                    // If no existing slots, provide full-day availability
                    if (existingSlots.isEmpty()) {
                        String eventTimezone = event.Event_Timezone__c != null ? event.Event_Timezone__c : 'America/Los_Angeles';
                        
                        // For days with no existing slots, create full-day availability (24 hours)
                        Datetime dayStartUTC = Datetime.newInstanceGmt(currentDate, Time.newInstance(0, 0, 0, 0));
                        Datetime dayEndUTC = Datetime.newInstanceGmt(currentDate, Time.newInstance(23, 59, 59, 0));
                        
                        dayAvailability.add(new LocationAvailability(
                            location.Id, location.Name, event.Id,
                            location.Room_Capacity__c, location.Room_Size__c,
                            currentDate, dayStartUTC, dayEndUTC, eventTimezone
                        ));
                        
                        System.debug('Added full-day availability for ' + currentDate + ': 24 hours (UTC)');
                    }
                    
                    // Add day availability to the location's availability periods
                    locationWithAvailability.availabilityPeriods.addAll(dayAvailability);
                    
                    currentDate = currentDate.addDays(1);
                }
                
                // Only add locations that have availability periods
                if (!locationWithAvailability.availabilityPeriods.isEmpty()) {
                    locationsWithAvailability.add(locationWithAvailability);
                }
            }
            
        // } catch (Exception e) {
        //     System.debug(LoggingLevel.ERROR, 'Error loading location availability: ' + e.getMessage());
        //     System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        // }
        // Convert to JSON strings for invocable method compatibility
        System.debug('locationsWithAvailability: ' + JSON.serialize(locationsWithAvailability));
        List<String> availabilityJsonStrings = new List<String>();
        
        // Build custom JSON with local timezone conversion
        List<Map<String, Object>> customJsonList = new List<Map<String, Object>>();
        
        for (LocationWithAvailability location : locationsWithAvailability) {
            Map<String, Object> locationMap = new Map<String, Object>();
            locationMap.put('roomSize', location.roomSize);
            locationMap.put('roomCapacity', location.roomCapacity);
            locationMap.put('locationName', location.locationName);
            locationMap.put('locationId', location.locationId);
            locationMap.put('eventId', location.eventId);
            
            List<Map<String, Object>> availabilityPeriods = new List<Map<String, Object>>();
            for (LocationAvailability period : location.availabilityPeriods) {
                Map<String, Object> periodMap = new Map<String, Object>();
                periodMap.put('roomSize', period.roomSize);
                periodMap.put('roomCapacity', period.roomCapacity);
                periodMap.put('locationName', period.locationName);
                periodMap.put('locationId', period.locationId);
                periodMap.put('eventId', period.eventId);
                periodMap.put('durationMinutes', period.durationMinutes);
                periodMap.put('availabilityStart', period.availabilityStartLocal);
                periodMap.put('availabilityEnd', period.availabilityEndLocal);
                periodMap.put('availabilityDate', period.availabilityDate != null ? period.availabilityDate.format() : null);
                
                availabilityPeriods.add(periodMap);
            }
            
            locationMap.put('availabilityPeriods', availabilityPeriods);
            customJsonList.add(locationMap);
        }
        
        availabilityJsonStrings.add(JSON.serialize(customJsonList));
        System.debug('final availabilityJsonStrings: ' + availabilityJsonStrings);
        return availabilityJsonStrings;
    }
    
    /**
     * @description Calculates available time slots for a specific day
     */
    private static List<LocationAvailability> calculateDayAvailability(
        Session_Location__c location, Event__c event, Date day, List<Session_Slot__c> existingSlots) {
        
        List<LocationAvailability> availability = new List<LocationAvailability>();
        
        // Get the event's timezone, default to Pacific Time if not set
        String eventTimezone = event.Event_Timezone__c != null ? event.Event_Timezone__c : 'America/Los_Angeles';
        
        System.debug('Day: ' + day + ', Event Timezone: ' + eventTimezone);
        
        // If no existing slots, return empty list - let the main method handle full-day availability
        if (existingSlots.isEmpty()) {
            return availability;
        }
        
        // Sort existing slots by start time
        existingSlots.sort(new SessionSlotComparator());
        
        // Find gaps between existing slots
        // Start with the first slot's start time, not midnight
        Datetime currentStart = null;
        
        for (Integer i = 0; i < existingSlots.size(); i++) {
            Session_Slot__c slot = existingSlots[i];
            
            // The Time field values represent UTC times (e.g., 14:00:00.000Z = 2 PM UTC)
            Time slotStartTime = slot.Start_Time__c;
            Time slotEndTime = slot.End_Time__c;
            
            // Create UTC datetime objects from the Time fields
            Datetime slotStartUTC = Datetime.newInstanceGmt(day, slotStartTime);
            Datetime slotEndUTC = Datetime.newInstanceGmt(day, slotEndTime);
            
            System.debug('Processing slot: Date=' + slot.Date__c + ', Day=' + day + ', Match=' + (slot.Date__c == day));
            System.debug('Slot UTC: ' + slotStartUTC + ' to ' + slotEndUTC);
            System.debug('Slot time values: Start=' + slotStartTime + ', End=' + slotEndTime);
            
            if (currentStart == null) {
                // First slot - start tracking from here
                currentStart = slotEndUTC;
            } else {
                // Check for gap between previous slot end and current slot start
                if (currentStart < slotStartUTC) {
                    System.debug('Adding availability gap: ' + currentStart + ' to ' + slotStartUTC);
                    availability.add(new LocationAvailability(
                        location.Id, location.Name, event.Id,
                        location.Room_Capacity__c, location.Room_Size__c,
                        day, currentStart, slotStartUTC, eventTimezone
                    ));
                }
                currentStart = slotEndUTC;
            }
        }
        
        // No need to add final availability period since we're only looking for gaps between slots
        // The main method will handle full-day availability for days with no existing slots
        
        // Debug: Show the availability with local times
        for (LocationAvailability avail : availability) {
            System.debug('Availability period: ' + avail.availabilityStartLocal + ' to ' + avail.availabilityEndLocal + ' (local time)');
        }
        System.debug('availability: ' + JSON.serialize(availability));
        return availability;
    }
    
    /**
     * @description Comparator class for sorting Session_Slot__c records by start time
     */
    private class SessionSlotComparator implements Comparator<Session_Slot__c> {
        public Integer compare(Session_Slot__c slot1, Session_Slot__c slot2) {
            if (slot1.Start_Time__c == null && slot2.Start_Time__c == null) return 0;
            if (slot1.Start_Time__c == null) return -1;
            if (slot2.Start_Time__c == null) return 1;
            
            // Convert Time to minutes since midnight for comparison
            Integer slot1Minutes = slot1.Start_Time__c.hour() * 60 + slot1.Start_Time__c.minute();
            Integer slot2Minutes = slot2.Start_Time__c.hour() * 60 + slot2.Start_Time__c.minute();
            
            if (slot1Minutes < slot2Minutes) return -1;
            if (slot1Minutes > slot2Minutes) return 1;
            return 0;
        }
    }
    
    /**
     * @description Default constructor
     */
    public LocationLoader() {
        // Default constructor
    }
}