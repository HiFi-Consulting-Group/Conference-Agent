/**
 * @description Loads session location availability by analyzing existing session slots
 *              and calculating available time periods within event constraints.
 * @Version 1.0
 */
public with sharing class LocationLoader {
    
    /**
     * @description Subclass representing a location's availability period
     */
    public class LocationAvailability {
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
            description='Date of availability'
        )
        public Date availabilityDate;
        
        @InvocableVariable(
            description='Start time of availability period'
        )
        public Datetime availabilityStart;
        
        @InvocableVariable(
            description='End time of availability period'
        )
        public Datetime availabilityEnd;
        
        @InvocableVariable(
            description='Duration of availability in minutes'
        )
        public Integer durationMinutes;
        
        /**
         * @description Constructor
         */
        public LocationAvailability() {
            this.locationId = null;
            this.locationName = '';
            this.eventId = null;
            this.roomCapacity = 0;
            this.roomSize = '';
            this.availabilityDate = null;
            this.availabilityStart = null;
            this.availabilityEnd = null;
            this.durationMinutes = 0;
        }
        
        /**
         * @description Constructor with parameters
         */
        public LocationAvailability(Id locationId, String locationName, Id eventId, 
                                   Decimal roomCapacity, String roomSize, 
                                   Date availabilityDate, Datetime availabilityStart, 
                                   Datetime availabilityEnd) {
            this.locationId = locationId;
            this.locationName = locationName;
            this.eventId = eventId;
            this.roomCapacity = roomCapacity != null ? roomCapacity : 0;
            this.roomSize = roomSize != null ? roomSize : '';
            this.availabilityDate = availabilityDate;
            this.availabilityStart = availabilityStart;
            this.availabilityEnd = availabilityEnd;
            this.durationMinutes = this.calculateDurationMinutes();
        }
        
        /**
         * @description Calculates duration in minutes
         */
        private Integer calculateDurationMinutes() {
            if (this.availabilityStart == null || this.availabilityEnd == null) {
                return 0;
            }
            
            Long durationMs = this.availabilityEnd.getTime() - this.availabilityStart.getTime();
            return (Integer)(durationMs / (1000 * 60)); // Convert milliseconds to minutes
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
            // Load events with their start/end dates
            Map<Id, Event__c> eventsMap = new Map<Id, Event__c>([
                SELECT Id, Event_Start_Date__c, Event_End_Date__c
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
            
            // Group session slots by location and date
            Map<String, List<Session_Slot__c>> slotsByLocationAndDate = new Map<String, List<Session_Slot__c>>();
            for (Session_Slot__c slot : sessionSlots) {
                String key = slot.Session_Location__c + '_' + slot.Date__c;
                if (!slotsByLocationAndDate.containsKey(key)) {
                    slotsByLocationAndDate.put(key, new List<Session_Slot__c>());
                }
                slotsByLocationAndDate.get(key).add(slot);
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
                    
                    // Calculate available time slots for this day
                    List<LocationAvailability> dayAvailability = calculateDayAvailability(
                        location, event, currentDate, existingSlots
                    );
                    
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
        availabilityJsonStrings.add(JSON.serialize(locationsWithAvailability));
        System.debug('availabilityJsonStrings: ' + availabilityJsonStrings);
        return availabilityJsonStrings;
    }
    
    /**
     * @description Calculates available time slots for a specific day
     */
    private static List<LocationAvailability> calculateDayAvailability(
        Session_Location__c location, Event__c event, Date day, List<Session_Slot__c> existingSlots) {
        
        List<LocationAvailability> availability = new List<LocationAvailability>();
        
        // Set business hours: 7 AM to 5 PM
        Time businessStart = Time.newInstance(7, 0, 0, 0);  // 7:00 AM
        Time businessEnd = Time.newInstance(17, 0, 0, 0);    // 5:00 PM
        
        // Create datetime objects for the day
        Datetime dayStart = Datetime.newInstance(day, businessStart);
        Datetime dayEnd = Datetime.newInstance(day, businessEnd);
        
        // Adjust for event boundaries
        if (day == event.Event_Start_Date__c.date()) {
            // First day: start from event start time or business start, whichever is later
            Time eventStartTime = event.Event_Start_Date__c.time();
            if (eventStartTime > businessStart) {
                dayStart = Datetime.newInstance(day, eventStartTime);
            }
            // Ensure we never start before business hours
            if (dayStart < Datetime.newInstance(day, businessStart)) {
                dayStart = Datetime.newInstance(day, businessStart);
            }
        }
        
        if (day == event.Event_End_Date__c.date()) {
            // Last day: end at event end time or business end, whichever is earlier
            Time eventEndTime = event.Event_End_Date__c.time();
            if (eventEndTime < businessEnd) {
                dayEnd = Datetime.newInstance(day, eventEndTime);
            }
            // Ensure we never end after business hours
            if (dayEnd > Datetime.newInstance(day, businessEnd)) {
                dayEnd = Datetime.newInstance(day, businessEnd);
            }
        }
        
        // If no existing slots, the entire business day is available
        if (existingSlots.isEmpty()) {
            if (dayStart < dayEnd) {
                availability.add(new LocationAvailability(
                    location.Id, location.Name, location.Event__c,
                    location.Room_Capacity__c, location.Room_Size__c,
                    day, dayStart, dayEnd
                ));
            }
            return availability;
        }
        
        // Sort existing slots by start time
        existingSlots.sort(new SessionSlotComparator());
        
        // Find gaps between existing slots
        Datetime currentStart = dayStart;
        
        for (Session_Slot__c slot : existingSlots) {
            Datetime slotStart = Datetime.newInstance(day, slot.Start_Time__c);
            Datetime slotEnd = Datetime.newInstance(day, slot.End_Time__c);
            
            // If there's a gap before this slot, add it as available
            if (currentStart < slotStart) {
                availability.add(new LocationAvailability(
                    location.Id, location.Name, location.Event__c,
                    location.Room_Capacity__c, location.Room_Size__c,
                    day, currentStart, slotStart
                ));
            }
            
            // Move current start to after this slot
            currentStart = slotEnd;
        }
        
        // If there's time remaining after the last slot, add it as available
        if (currentStart < dayEnd) {
            availability.add(new LocationAvailability(
                location.Id, location.Name, location.Event__c,
                location.Room_Capacity__c, location.Room_Size__c,
                day, currentStart, dayEnd
            ));
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