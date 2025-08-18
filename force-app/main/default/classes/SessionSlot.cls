/**
 * @description Wrapper class for Session_Slot__c object to provide a clean interface
 *              for working with Session Slot records in the conference scheduling system.
 * @Version 1.0
 */
public with sharing class SessionSlot {
    
    // Properties
    @InvocableVariable(
        description='Session Slot Record Id'
    )
    public Id sessionSlotId;
    
    @InvocableVariable(
        description='Session this slot belongs to'
    )
    public Id sessionId;
    
    @InvocableVariable(
        description='Session Location/Room for this slot'
    )
    public Id sessionLocationId;
    
    @InvocableVariable(
        description='Date of the session slot'
    )
    public Date slotDate;
    
    @InvocableVariable(
        description='Start time of the session slot'
    )
    public Time startTime;
    
    @InvocableVariable(
        description='End time of the session slot'
    )
    public Time endTime;
    
    @InvocableVariable(
        description='Session Name (from related Session)'
    )
    public String sessionName;
    
    @InvocableVariable(
        description='Location Name (from related Session Location)'
    )
    public String locationName;
    
    @InvocableVariable(
        description='Room Capacity (from related Session Location)'
    )
    public Decimal roomCapacity;
    
    @InvocableVariable(
        description='Room Size Category (from related Session Location)'
    )
    public String roomSize;
    
    @InvocableVariable(
        description='Indicates if this is a draft session slot (not yet finalized)'
    )
    public Boolean isDraft;
    
    // Default constructor
    public SessionSlot() {
        this.sessionSlotId = null;
        this.sessionId = null;
        this.sessionLocationId = null;
        this.slotDate = null;
        this.startTime = null;
        this.endTime = null;
        this.sessionName = '';
        this.locationName = '';
        this.roomCapacity = 0;
        this.roomSize = '';
        this.isDraft = false;
    }
    
    // Constructor with Session_Slot__c record
    public SessionSlot(Session_Slot__c sessionSlotRecord) {
        this.sessionSlotId = sessionSlotRecord.Id;
        this.sessionId = sessionSlotRecord.Session__c;
        this.sessionLocationId = sessionSlotRecord.Session_Location__c;
        this.slotDate = sessionSlotRecord.Date__c;
        this.startTime = sessionSlotRecord.Start_Time__c;
        this.endTime = sessionSlotRecord.End_Time__c;
        this.sessionName = '';
        this.locationName = '';
        this.roomCapacity = 0;
        this.roomSize = '';
        this.isDraft = sessionSlotRecord.Draft__c != null ? sessionSlotRecord.Draft__c : false;
    }
    
    // Constructor with Session_Slot__c record and related details
    public SessionSlot(Session_Slot__c sessionSlotRecord, Session__c session, Session_Location__c location) {
        this.sessionSlotId = sessionSlotRecord.Id;
        this.sessionId = sessionSlotRecord.Session__c;
        this.sessionLocationId = sessionSlotRecord.Session_Location__c;
        this.slotDate = sessionSlotRecord.Date__c;
        this.startTime = sessionSlotRecord.Start_Time__c;
        this.endTime = sessionSlotRecord.End_Time__c;
        
        // Session details
        this.sessionName = session != null ? session.Name : '';
        
        // Location details
        this.locationName = location != null ? location.Name : '';
        this.roomCapacity = location != null && location.Room_Capacity__c != null ? 
            location.Room_Capacity__c : 0;
        this.roomSize = location != null ? location.Room_Size__c : '';
        
        // Draft status
        this.isDraft = sessionSlotRecord.Draft__c != null ? sessionSlotRecord.Draft__c : false;
    }
    
    // Constructor with individual parameters
    public SessionSlot(Id sessionId, Id sessionLocationId, Date slotDate, Time startTime, Time endTime) {
        this.sessionSlotId = null;
        this.sessionId = sessionId;
        this.sessionLocationId = sessionLocationId;
        this.slotDate = slotDate;
        this.startTime = startTime;
        this.endTime = endTime;
        this.sessionName = '';
        this.locationName = '';
        this.roomCapacity = 0;
        this.roomSize = '';
        this.isDraft = false;
    }
    
    // Constructor with session and location details
    public SessionSlot(Id sessionId, Id sessionLocationId, Date slotDate, Time startTime, Time endTime,
                       String sessionName, String locationName, Decimal roomCapacity, String roomSize) {
        this.sessionSlotId = null;
        this.sessionId = sessionId;
        this.sessionLocationId = sessionLocationId;
        this.slotDate = slotDate;
        this.startTime = startTime;
        this.endTime = endTime;
        this.sessionName = sessionName != null ? sessionName : '';
        this.locationName = locationName != null ? locationName : '';
        this.roomCapacity = roomCapacity != null ? roomCapacity : 0;
        this.roomSize = roomSize != null ? roomSize : '';
        this.isDraft = false;
    }
    
    // Constructor with draft status
    public SessionSlot(Id sessionId, Id sessionLocationId, Date slotDate, Time startTime, Time endTime, Boolean isDraft) {
        this.sessionSlotId = null;
        this.sessionId = sessionId;
        this.sessionLocationId = sessionLocationId;
        this.slotDate = slotDate;
        this.startTime = startTime;
        this.endTime = endTime;
        this.sessionName = '';
        this.locationName = '';
        this.roomCapacity = 0;
        this.roomSize = '';
        this.isDraft = isDraft != null ? isDraft : false;
    }
    
    /**
     * @description Gets the duration of the session slot in minutes
     * @return Integer duration in minutes
     */
    public Integer getDurationMinutes() {
        if (this.startTime == null || this.endTime == null) {
            return 0;
        }
        
        // Convert Time to minutes since midnight
        Integer startMinutes = this.startTime.hour() * 60 + this.startTime.minute();
        Integer endMinutes = this.endTime.hour() * 60 + this.endTime.minute();
        
        // Handle overnight sessions (end time is next day)
        if (endMinutes < startMinutes) {
            endMinutes += 24 * 60; // Add 24 hours
        }
        
        return endMinutes - startMinutes;
    }
    
    /**
     * @description Gets the duration of the session slot in hours
     * @return Decimal duration in hours
     */
    public Decimal getDurationHours() {
        Integer minutes = this.getDurationMinutes();
        return minutes > 0 ? (minutes / 60.0).setScale(2) : 0;
    }
    
    /**
     * @description Checks if the session slot is currently active
     * @return Boolean indicating if slot is currently happening
     */
    public Boolean isCurrentlyActive() {
        if (this.slotDate == null || this.startTime == null || this.endTime == null) {
            return false;
        }
        
        Date today = Date.today();
        Time now = DateTime.now().time();
        
        // Check if it's today and current time is within the slot
        if (this.slotDate == today) {
            return now >= this.startTime && now <= this.endTime;
        }
        
        return false;
    }
    
    /**
     * @description Checks if the session slot has ended
     * @return Boolean indicating if slot has ended
     */
    public Boolean hasEnded() {
        if (this.slotDate == null || this.endTime == null) {
            return false;
        }
        
        Date today = Date.today();
        Time now = DateTime.now().time();
        
        // Check if it's today and current time is past the end time
        if (this.slotDate == today) {
            return now > this.endTime;
        }
        
        // Check if it's a past date
        return this.slotDate < today;
    }
    
    /**
     * @description Checks if the session slot is in the future
     * @return Boolean indicating if slot is in the future
     */
    public Boolean isInFuture() {
        if (this.slotDate == null) {
            return false;
        }
        
        Date today = Date.today();
        
        // If it's today, check if start time is in the future
        if (this.slotDate == today && this.startTime != null) {
            Time now = DateTime.now().time();
            return now < this.startTime;
        }
        
        // Check if it's a future date
        return this.slotDate > today;
    }
    
    /**
     * @description Gets a formatted time range string
     * @return String formatted time range (e.g., "9:00 AM - 10:30 AM")
     */
    public String getFormattedTimeRange() {
        if (this.startTime == null || this.endTime == null) {
            return '';
        }
        
        String startTimeStr = this.formatTime(this.startTime);
        String endTimeStr = this.formatTime(this.endTime);
        
        return startTimeStr + ' - ' + endTimeStr;
    }
    
    /**
     * @description Gets a formatted date string
     * @return String formatted date
     */
    public String getFormattedDate() {
        if (this.slotDate == null) {
            return '';
        }
        
        return this.slotDate.format();
    }
    
    /**
     * @description Gets a display name for the slot
     * @return String display name
     */
    public String getDisplayName() {
        if (String.isNotBlank(this.sessionName)) {
            return this.sessionName + ' - ' + this.getFormattedTimeRange();
        }
        return 'Session Slot - ' + this.getFormattedTimeRange();
    }
    
    /**
     * @description Gets a display name that indicates draft status
     * @return String display name with draft indicator
     */
    public String getDisplayNameWithStatus() {
        String baseName = this.getDisplayName();
        if (this.isDraft) {
            return baseName + ' (Draft)';
        }
        return baseName + ' (Finalized)';
    }
    
    /**
     * @description Checks if the session slot is finalized (not a draft)
     * @return Boolean indicating if slot is finalized
     */
    public Boolean isFinalized() {
        return !this.isDraft;
    }
    
    /**
     * @description Gets the status description of the slot
     * @return String status description
     */
    public String getStatusDescription() {
        return this.isDraft ? 'Draft' : 'Finalized';
    }
    
    /**
     * @description Formats a Time object to readable string
     * @param timeValue The Time to format
     * @return String formatted time
     */
    private String formatTime(Time timeValue) {
        if (timeValue == null) return '';
        
        Integer hour = timeValue.hour();
        Integer minute = timeValue.minute();
        String ampm = hour >= 12 ? 'PM' : 'AM';
        
        // Convert to 12-hour format
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        
        return String.valueOf(hour) + ':' + 
               (minute < 10 ? '0' + String.valueOf(minute) : String.valueOf(minute)) + 
               ' ' + ampm;
    }
    
    /**
     * @description Converts the wrapper back to a Session_Slot__c record
     * @return Session_Slot__c record
     */
    public Session_Slot__c toSessionSlotRecord() {
        Session_Slot__c sessionSlotRecord = new Session_Slot__c();
        if (this.sessionSlotId != null) {
            sessionSlotRecord.Id = this.sessionSlotId;
        }
        sessionSlotRecord.Session__c = this.sessionId;
        sessionSlotRecord.Session_Location__c = this.sessionLocationId;
        sessionSlotRecord.Date__c = this.slotDate;
        sessionSlotRecord.Start_Time__c = this.startTime;
        sessionSlotRecord.End_Time__c = this.endTime;
        sessionSlotRecord.Draft__c = this.isDraft;
        return sessionSlotRecord;
    }
    
    /**
     * @description Creates a list of SessionSlot wrapper objects from a list of Session_Slot__c records
     * @param sessionSlotRecords List of Session_Slot__c records
     * @return List of SessionSlot wrapper objects
     */
    public static List<SessionSlot> fromSessionSlotRecords(List<Session_Slot__c> sessionSlotRecords) {
        List<SessionSlot> sessionSlots = new List<SessionSlot>();
        if (sessionSlotRecords != null) {
            for (Session_Slot__c sessionSlotRecord : sessionSlotRecords) {
                sessionSlots.add(new SessionSlot(sessionSlotRecord));
            }
        }
        return sessionSlots;
    }
    
    /**
     * @description Creates a list of Session_Slot__c records from a list of SessionSlot wrapper objects
     * @param sessionSlots List of SessionSlot wrapper objects
     * @return List of Session_Slot__c records
     */
    public static List<Session_Slot__c> toSessionSlotRecords(List<SessionSlot> sessionSlots) {
        List<Session_Slot__c> sessionSlotRecords = new List<Session_Slot__c>();
        if (sessionSlots != null) {
            for (SessionSlot sessionSlot : sessionSlots) {
                sessionSlotRecords.add(sessionSlot.toSessionSlotRecord());
            }
        }
        return sessionSlotRecords;
    }
} 