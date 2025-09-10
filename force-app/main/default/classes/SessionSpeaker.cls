/**
 * @description Wrapper class for Session_Speaker__c object to provide a clean interface
 *              for working with Session Speaker records in the conference scheduling system.
 * @Version 1.0
 */
public with sharing class SessionSpeaker {
    
    // Properties
    @InvocableVariable(
        description='Session Speaker Record Id'
    )
    public Id sessionSpeakerId;
    
    @InvocableVariable(
        description='Session this speaker is associated with'
    )
    public Id sessionId;
    
    @InvocableVariable(
        description='Speaker Contact Id'
    )
    public Id speakerId;
    
    @InvocableVariable(
        description='Speaker First Name'
    )
    public String speakerFirstName;
    
    @InvocableVariable(
        description='Speaker Last Name'
    )
    public String speakerLastName;
    
    @InvocableVariable(
        description='Speaker Full Name'
    )
    public String speakerFullName;
    
    @InvocableVariable(
        description='Speaker Email'
    )
    public String speakerEmail;
    
    @InvocableVariable(
        description='Speaker Company/Organization'
    )
    public String speakerCompany;
    
    @InvocableVariable(
        description='Speaker Title/Role'
    )
    public String speakerTitle;
    
    @InvocableVariable(
        description='Speaker Bio'
    )
    public String speakerBio;
    
    // Default constructor
    public SessionSpeaker() {
        this.sessionSpeakerId = null;
        this.sessionId = null;
        this.speakerId = null;
        this.speakerFirstName = '';
        this.speakerLastName = '';
        this.speakerFullName = '';
        this.speakerEmail = '';
        this.speakerCompany = '';
        this.speakerTitle = '';
        this.speakerBio = '';
    }
    
    // Constructor with Session_Speaker__c record
    public SessionSpeaker(Session_Speaker__c sessionSpeakerRecord) {
        this.sessionSpeakerId = sessionSpeakerRecord.Id;
        this.sessionId = sessionSpeakerRecord.Session__c;
        this.speakerId = sessionSpeakerRecord.Speaker__c;
        this.speakerFirstName = '';
        this.speakerLastName = '';
        this.speakerFullName = '';
        this.speakerEmail = '';
        this.speakerCompany = '';
        this.speakerTitle = '';
        this.speakerBio = '';
    }
    
    // Constructor with Session_Speaker__c record and Speaker details
    public SessionSpeaker(Session_Speaker__c sessionSpeakerRecord, Contact speakerContact) {
        this.sessionSpeakerId = sessionSpeakerRecord.Id;
        this.sessionId = sessionSpeakerRecord.Session__c;
        this.speakerId = sessionSpeakerRecord.Speaker__c;
        this.speakerFirstName = speakerContact.FirstName != null ? speakerContact.FirstName : '';
        this.speakerLastName = speakerContact.LastName != null ? speakerContact.LastName : '';
        this.speakerFullName = this.buildFullName();
        this.speakerEmail = speakerContact.Email != null ? speakerContact.Email : '';
        this.speakerCompany = speakerContact.Account != null ? speakerContact.Account.Name : '';
        this.speakerTitle = speakerContact.Title != null ? speakerContact.Title : '';
        this.speakerBio = '';
    }
    
    // Constructor with individual parameters
    public SessionSpeaker(Id sessionId, Id speakerId) {
        this.sessionSpeakerId = null;
        this.sessionId = sessionId;
        this.speakerId = speakerId;
        this.speakerFirstName = '';
        this.speakerLastName = '';
        this.speakerFullName = '';
        this.speakerEmail = '';
        this.speakerCompany = '';
        this.speakerTitle = '';
        this.speakerBio = '';
    }
    
    // Constructor with speaker details
    public SessionSpeaker(Id sessionId, String firstName, String lastName, String email) {
        this.sessionSpeakerId = null;
        this.sessionId = sessionId;
        this.speakerId = null;
        this.speakerFirstName = firstName != null ? firstName : '';
        this.speakerLastName = lastName != null ? lastName : '';
        this.speakerFullName = this.buildFullName();
        this.speakerEmail = email != null ? email : '';
        this.speakerCompany = '';
        this.speakerTitle = '';
        this.speakerBio = '';
    }
    
    /**
     * @description Builds the full name from first and last name
     * @return String full name
     */
    public String buildFullName() {
        if (String.isNotBlank(this.speakerFirstName) && String.isNotBlank(this.speakerLastName)) {
            return this.speakerFirstName + ' ' + this.speakerLastName;
        } else if (String.isNotBlank(this.speakerFirstName)) {
            return this.speakerFirstName;
        } else if (String.isNotBlank(this.speakerLastName)) {
            return this.speakerLastName;
        }
        return '';
    }
    
    /**
     * @description Updates the full name based on current first and last name
     */
    public void updateFullName() {
        this.speakerFullName = this.buildFullName();
    }
    
    /**
     * @description Sets the speaker's first name and updates full name
     * @param firstName The first name to set
     */
    public void setFirstName(String firstName) {
        this.speakerFirstName = firstName != null ? firstName : '';
        this.speakerFullName = this.buildFullName();
    }
    
    /**
     * @description Sets the speaker's last name and updates full name
     * @param lastName The last name to set
     */
    public void setLastName(String lastName) {
        this.speakerLastName = lastName != null ? lastName : '';
        this.speakerFullName = this.buildFullName();
    }
    
    /**
     * @description Checks if the speaker has a complete name
     * @return Boolean indicating if speaker has both first and last name
     */
    public Boolean hasCompleteName() {
        return String.isNotBlank(this.speakerFirstName) && String.isNotBlank(this.speakerLastName);
    }
    
    /**
     * @description Checks if the speaker has contact information
     * @return Boolean indicating if speaker has email or company info
     */
    public Boolean hasContactInfo() {
        return String.isNotBlank(this.speakerEmail) || String.isNotBlank(this.speakerCompany);
    }
    
    /**
     * @description Gets a display name for the speaker (full name or company if no name)
     * @return String display name
     */
    public String getDisplayName() {
        if (String.isNotBlank(this.speakerFullName)) {
            return this.speakerFullName;
        } else if (String.isNotBlank(this.speakerCompany)) {
            return this.speakerCompany;
        } else if (String.isNotBlank(this.speakerFirstName)) {
            return this.speakerFirstName;
        } else if (String.isNotBlank(this.speakerLastName)) {
            return this.speakerLastName;
        }
        return 'Unknown Speaker';
    }
    
    /**
     * @description Gets a short display name (first name only if available)
     * @return String short display name
     */
    public String getShortDisplayName() {
        if (String.isNotBlank(this.speakerFirstName)) {
            return this.speakerFirstName;
        } else if (String.isNotBlank(this.speakerLastName)) {
            return this.speakerLastName;
        } else if (String.isNotBlank(this.speakerCompany)) {
            return this.speakerCompany;
        }
        return 'Speaker';
    }
    
    /**
     * @description Converts the wrapper back to a Session_Speaker__c record
     * @return Session_Speaker__c record
     */
    public Session_Speaker__c toSessionSpeakerRecord() {
        Session_Speaker__c sessionSpeakerRecord = new Session_Speaker__c();
        if (this.sessionSpeakerId != null) {
            sessionSpeakerRecord.Id = this.sessionSpeakerId;
        }
        sessionSpeakerRecord.Session__c = this.sessionId;
        sessionSpeakerRecord.Speaker__c = this.speakerId;
        return sessionSpeakerRecord;
    }
    
    /**
     * @description Creates a Contact record for this speaker
     * @return Contact record
     */
    public Contact toContactRecord() {
        Contact contactRecord = new Contact();
        if (this.speakerId != null) {
            contactRecord.Id = this.speakerId;
        }
        contactRecord.FirstName = this.speakerFirstName;
        contactRecord.LastName = this.speakerLastName;
        contactRecord.Email = this.speakerEmail;
        contactRecord.Title = this.speakerTitle;
        return contactRecord;
    }
    
    /**
     * @description Creates a list of SessionSpeaker wrapper objects from a list of Session_Speaker__c records
     * @param sessionSpeakerRecords List of Session_Speaker__c records
     * @return List of SessionSpeaker wrapper objects
     */
    public static List<SessionSpeaker> fromSessionSpeakerRecords(List<Session_Speaker__c> sessionSpeakerRecords) {
        List<SessionSpeaker> sessionSpeakers = new List<SessionSpeaker>();
        if (sessionSpeakerRecords != null) {
            for (Session_Speaker__c sessionSpeakerRecord : sessionSpeakerRecords) {
                sessionSpeakers.add(new SessionSpeaker(sessionSpeakerRecord));
            }
        }
        return sessionSpeakers;
    }
    
    /**
     * @description Creates a list of Session_Speaker__c records from a list of SessionSpeaker wrapper objects
     * @param sessionSpeakers List of SessionSpeaker wrapper objects
     * @return List of Session_Speaker__c records
     */
    public static List<Session_Speaker__c> toSessionSpeakerRecords(List<SessionSpeaker> sessionSpeakers) {
        List<Session_Speaker__c> sessionSpeakerRecords = new List<Session_Speaker__c>();
        if (sessionSpeakers != null) {
            for (SessionSpeaker sessionSpeaker : sessionSpeakers) {
                sessionSpeakerRecords.add(sessionSpeaker.toSessionSpeakerRecord());
            }
        }
        return sessionSpeakerRecords;
    }
}