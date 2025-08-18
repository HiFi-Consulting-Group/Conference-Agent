/**
 * @description Wrapper class for Event__c object to provide a clean interface
 *              for working with Event records in the conference scheduling system.
 * @Version 1.0
 */
public with sharing class Event {
    
    // Properties
    @InvocableVariable(
        description='Event Record Id'
    )
    public Id eventId;
    
    @InvocableVariable(
        description='Event Name'
    )
    public String eventName;
    
    @InvocableVariable(
        description='Event Start Date and Time'
    )
    public DateTime startDateTime;
    
    @InvocableVariable(
        description='Event End Date and Time'
    )
    public DateTime endDateTime;
    
    @InvocableVariable(
        description='Event Duration in Days'
    )
    public Integer eventDurationDays;
    
    @InvocableVariable(
        description='Event Duration in Hours'
    )
    public Decimal eventDurationHours;
    
    // Default constructor
    public Event() {
        this.eventId = null;
        this.eventName = '';
        this.startDateTime = null;
        this.endDateTime = null;
        this.eventDurationDays = 0;
        this.eventDurationHours = 0.0;
    }
    
    // Constructor with Event__c record
    public Event(Event__c eventRecord) {
        this.eventId = eventRecord.Id;
        this.eventName = eventRecord.Name;
        this.startDateTime = eventRecord.Event_Start_Date__c;
        this.endDateTime = eventRecord.Event_End_Date__c;
        this.calculateDurations();
    }
    
    // Constructor with individual parameters
    public Event(Id eventId, String eventName, DateTime startDateTime, DateTime endDateTime) {
        this.eventId = eventId;
        this.eventName = eventName;
        this.startDateTime = startDateTime;
        this.endDateTime = endDateTime;
        this.calculateDurations();
    }
    
    // Constructor with name and dates only
    public Event(String eventName, DateTime startDateTime, DateTime endDateTime) {
        this.eventId = null;
        this.eventName = eventName;
        this.startDateTime = startDateTime;
        this.endDateTime = endDateTime;
        this.calculateDurations();
    }
    
    /**
     * @description Calculates the duration of the event in days and hours
     */
    private void calculateDurations() {
        if (this.startDateTime != null && this.endDateTime != null) {
            // Calculate duration in milliseconds
            Long startTime = this.startDateTime.getTime();
            Long endTime = this.endDateTime.getTime();
            Long durationMs = endTime - startTime;
            
            // Convert to days and hours
            this.eventDurationDays = (Integer) (durationMs / (1000 * 60 * 60 * 24));
            this.eventDurationHours = (durationMs / (1000.0 * 60 * 60)).setScale(2);
        } else {
            this.eventDurationDays = 0;
            this.eventDurationHours = 0.0;
        }
    }
    
    /**
     * @description Checks if the event is currently active
     * @return Boolean indicating if the event is currently happening
     */
    public Boolean isCurrentlyActive() {
        if (this.startDateTime == null || this.endDateTime == null) {
            return false;
        }
        
        DateTime now = DateTime.now();
        return now >= this.startDateTime && now <= this.endDateTime;
    }
    
    /**
     * @description Checks if the event has ended
     * @return Boolean indicating if the event has ended
     */
    public Boolean hasEnded() {
        if (this.endDateTime == null) {
            return false;
        }
        
        return DateTime.now() > this.endDateTime;
    }
    
    /**
     * @description Checks if the event is in the future
     * @return Boolean indicating if the event is in the future
     */
    public Boolean isInFuture() {
        if (this.startDateTime == null) {
            return false;
        }
        
        return DateTime.now() < this.startDateTime;
    }
    
    /**
     * @description Converts the wrapper back to an Event__c record
     * @return Event__c record
     */
    public Event__c toEventRecord() {
        Event__c eventRecord = new Event__c();
        if (this.eventId != null) {
            eventRecord.Id = this.eventId;
        }
        eventRecord.Name = this.eventName;
        eventRecord.Event_Start_Date__c = this.startDateTime;
        eventRecord.Event_End_Date__c = this.endDateTime;
        return eventRecord;
    }
    
    /**
     * @description Creates a list of Event wrapper objects from a list of Event__c records
     * @param eventRecords List of Event__c records
     * @return List of Event wrapper objects
     */
    public static List<Event> fromEventRecords(List<Event__c> eventRecords) {
        List<Event> events = new List<Event>();
        if (eventRecords != null) {
            for (Event__c eventRecord : eventRecords) {
                events.add(new Event(eventRecord));
            }
        }
        return events;
    }
    
    /**
     * @description Creates a list of Event__c records from a list of Event wrapper objects
     * @param events List of Event wrapper objects
     * @return List of Event__c records
     */
    public static List<Event__c> toEventRecords(List<Event> events) {
        List<Event__c> eventRecords = new List<Event__c>();
        if (events != null) {
            for (Event event : events) {
                eventRecords.add(event.toEventRecord());
            }
        }
        return eventRecords;
    }
}