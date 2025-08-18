/**
 * @description Wrapper class for Session__c object to provide a clean interface
 *              for working with Session records in the conference scheduling system.
 * @Version 1.0
 */
public with sharing class Session {
    
    // Properties
    @InvocableVariable(
        description='Session Record Id'
    )
    public Id sessionId;
    
    @InvocableVariable(
        description='Session Name'
    )
    public String sessionName;
    
    @InvocableVariable(
        description='Event this session belongs to'
    )
    public Id eventId;
    
    @InvocableVariable(
        description='Session Abstract/Description'
    )
    public String sessionAbstract;
    
    @InvocableVariable(
        description='Session Format (Presentation, Demo, HOT, Panel, Keynote)'
    )
    public String format;
    
    @InvocableVariable(
        description='Session Focus Area'
    )
    public String focus;
    
    @InvocableVariable(
        description='Requested Room Size (Small, Medium, Large)'
    )
    public String requestedRoomSize;
    
    @InvocableVariable(
        description='Session Length in Minutes'
    )
    public Decimal sessionLengthMinutes;
    
    @InvocableVariable(
        description='List of speakers for this session'
    )
    public List<SessionSpeaker> speakers;
    
    // Read-only properties for formula/summary fields
    @InvocableVariable(
        description='Whether the session has been scheduled (read-only)'
    )
    public Boolean isScheduled;
    
    @InvocableVariable(
        description='Number of Session Slots (read-only)'
    )
    public Decimal sessionSlotCount;

    @InvocableVariable(
        description='Whether the session has a draft session slot (read-only)'
    )
    public Boolean hasDraftSessionSlot;

    @InvocableVariable(
        description='Whether the session has a finalized session slot (read-only)'
    )
    public Boolean hasFinalizedSessionSlot;

    @InvocableVariable(
        description='List of session slots for this session'
    )
    public List < SessionSlot > sessionSlots;

    
    // Default constructor
    public Session() {
        this.sessionId = null;
        this.sessionName = '';
        this.eventId = null;
        this.sessionAbstract = '';
        this.format = '';
        this.focus = '';
        this.requestedRoomSize = '';
        this.sessionLengthMinutes = 0;
        this.speakers = new List<SessionSpeaker>();
        this.isScheduled = false;
        this.sessionSlotCount = 0;
        this.hasDraftSessionSlot = false;
        this.hasFinalizedSessionSlot = false;
        this.sessionSlots = new List<SessionSlot>();
    }
    
    // Constructor with Session__c record
    public Session(Session__c sessionRecord) {
        this.sessionId = sessionRecord.Id;
        this.sessionName = sessionRecord.Name;
        this.eventId = sessionRecord.Event__c;
        this.sessionAbstract = sessionRecord.Session_Abstract__c;
        this.format = sessionRecord.Format__c;
        this.focus = sessionRecord.Focus__c;
        this.requestedRoomSize = sessionRecord.Requested_Room_Size__c;
        this.sessionLengthMinutes = sessionRecord.Session_Length_Minutes__c != null ? 
            sessionRecord.Session_Length_Minutes__c : 0;
        this.speakers = new List<SessionSpeaker>();
        
        // Read-only fields from formula/summary
        this.isScheduled = sessionRecord.Scheduled__c != null ? sessionRecord.Scheduled__c : false;
        this.sessionSlotCount = sessionRecord.Session_Slot_Count__c != null ? 
            sessionRecord.Session_Slot_Count__c : 0;
        this.sessionSlots = new List<SessionSlot>();
        //If there are Session_Slots__r, then add them to the sessionSlots list 
        if (sessionRecord.Session_Slots__r != null) {
            for (Session_Slot__c sessionSlot : sessionRecord.Session_Slots__r) {
                this.sessionSlots.add(new SessionSlot(sessionSlot));
            }
        }
    }
    
    // Constructor with individual parameters
    public Session(Id sessionId, String sessionName, Id eventId, String sessionAbstract, 
                   String format, String focus, String requestedRoomSize, 
                   Decimal sessionLengthMinutes) {
        this.sessionId = sessionId;
        this.sessionName = sessionName;
        this.eventId = eventId;
        this.sessionAbstract = sessionAbstract;
        this.format = format;
        this.focus = focus;
        this.requestedRoomSize = requestedRoomSize;
        this.sessionLengthMinutes = sessionLengthMinutes;
        this.speakers = new List<SessionSpeaker>();
        this.isScheduled = false;
        this.sessionSlotCount = 0;
        this.sessionSlots = new List<SessionSlot>();
    }
    
    /**
     * @description Adds a speaker to this session
     * @param speaker The SessionSpeaker to add
     */
    public void addSpeaker(SessionSpeaker speaker) {
        if (this.speakers == null) {
            this.speakers = new List<SessionSpeaker>();
        }
        this.speakers.add(speaker);
    }
    
    /**
     * @description Removes a speaker from this session
     * @param speakerId The ID of the speaker to remove
     * @return Boolean indicating if speaker was found and removed
     */
    public Boolean removeSpeaker(Id speakerId) {
        if (this.speakers == null) {
            return false;
        }
        
        for (Integer i = 0; i < this.speakers.size(); i++) {
            if (this.speakers[i].speakerId == speakerId) {
                this.speakers.remove(i);
                return true;
            }
        }
        return false;
    }
    
    /**
     * @description Gets the number of speakers for this session
     * @return Integer count of speakers
     */
    public Integer getSpeakerCount() {
        return this.speakers != null ? this.speakers.size() : 0;
    }
    
    /**
     * @description Checks if the session has any speakers
     * @return Boolean indicating if session has speakers
     */
    public Boolean hasSpeakers() {
        return this.speakers != null && !this.speakers.isEmpty();
    }
    
    /**
     * @description Checks if the session is a keynote (highest priority)
     * @return Boolean indicating if session is a keynote
     */
    public Boolean isKeynote() {
        return 'Keynote'.equalsIgnoreCase(this.format);
    }
    
    /**
     * @description Checks if the session requires hands-on training setup
     * @return Boolean indicating if session is hands-on training
     */
    public Boolean isHandsOnTraining() {
        return 'Hands-On Training (HOT)'.equalsIgnoreCase(this.format);
    }
    
    /**
     * @description Gets the room size category as a number for sorting
     * @return Integer representing room size (1=Small, 2=Medium, 3=Large)
     */
    public Integer getRoomSizeCategory() {
        if (this.requestedRoomSize == null) return 0;
        
        switch on this.requestedRoomSize.toLowerCase() {
            when 'small (under 50)' { return 1; }
            when 'medium (50-150)' { return 2; }
            when 'large (151+)' { return 3; }
            when else { return 0; }
        }
    }
    
    /**
     * @description Converts the wrapper back to a Session__c record
     * @return Session__c record
     */
    public Session__c toSessionRecord() {
        Session__c sessionRecord = new Session__c();
        if (this.sessionId != null) {
            sessionRecord.Id = this.sessionId;
        }
        sessionRecord.Name = this.sessionName;
        sessionRecord.Event__c = this.eventId;
        sessionRecord.Session_Abstract__c = this.sessionAbstract;
        sessionRecord.Format__c = this.format;
        sessionRecord.Focus__c = this.focus;
        sessionRecord.Requested_Room_Size__c = this.requestedRoomSize;
        sessionRecord.Session_Length_Minutes__c = this.sessionLengthMinutes;
        
        // Note: Scheduled__c and Session_Slot_Count__c are formula/summary fields
        // and cannot be written to - they are calculated automatically
        return sessionRecord;
    }
    
    /**
     * @description Creates a list of Session wrapper objects from a list of Session__c records
     * @param sessionRecords List of Session__c records
     * @return List of Session wrapper objects
     */
    public static List<Session> fromSessionRecords(List<Session__c> sessionRecords) {
        List<Session> sessions = new List<Session>();
        if (sessionRecords != null) {
            for (Session__c sessionRecord : sessionRecords) {
                sessions.add(new Session(sessionRecord));
            }
        }
        return sessions;
    }
    
    /**
     * @description Creates a list of Session__c records from a list of Session wrapper objects
     * @param sessions List of Session wrapper objects
     * @return List of Session__c records
     */
    public static List<Session__c> toSessionRecords(List<Session> sessions) {
        List<Session__c> sessionRecords = new List<Session__c>();
        if (sessions != null) {
            for (Session session : sessions) {
                sessionRecords.add(session.toSessionRecord());
            }
        }
        return sessionRecords;
    }
} 