public with sharing class ScheduleAgentController {
    @InvocableMethod(
        label='Load Sessions that need to be scheduled'
        description='This will load all Sesson\'s that do not yet have a Session Slot scheduled'
    )
    public static List<SessionArray> getSessionsToSchedule(List < SessionInput > input) {
        List < Session__c > sessions = [SELECT Id, Name, Requested_Room_Size__c, Session_Length_Minutes__c, Scheduled__c, (SELECT ID, Speaker__c, Speaker__r.FirstName, Speaker__r.LastName, Speaker__r.Email FROM Session_Speakers__r) FROM Session__c LIMIT 25];

        List < ScheduleAgentController.Session > sessionsToSchedule = new List < ScheduleAgentController.Session > ();
        for (Session__c ses: sessions) {
            List < ScheduleAgentController.Speaker > speakerList = new List < ScheduleAgentController.Speaker > ();
            for (Session_Speaker__c sessionSpeaker: ses.Session_Speakers__r) {
                ScheduleAgentController.Speaker speaker = new ScheduleAgentController.Speaker(sessionSpeaker.Speaker__r.FirstName, sessionSpeaker.Speaker__r.LastName, sessionSpeaker.Speaker__r.Email, sessionSpeaker.Speaker__r.Id);
                speakerList.add(speaker);
            }
            ScheduleAgentController.Session session = new ScheduleAgentController.Session(ses.Id, ses.Requested_Room_Size__c, speakerList, Integer.valueOf(ses.Session_Length_Minutes__c), ses.Scheduled__c, ses.Name);
            sessionsToSchedule.add(session);
        }
        System.debug('Sessions to Schedule: ' + JSON.serialize(sessionsToSchedule));

        ScheduleAgentController.SessionArray sessionsArray = new ScheduleAgentController.SessionArray(sessionsToSchedule);
        List < ScheduleAgentController.SessionArray > sessionsArrayAsList = new List < ScheduleAgentController.SessionArray > ();
        sessionsArrayAsList.add(sessionsArray);
        System.debug('Sessions to Schedule: ' + JSON.serialize(sessionsArrayAsList));
        return sessionsArrayAsList;

    }

    public class SessionArray {
        @InvocableVariable(
            description='Session Array'
        )
        public List<Session> sessionArray;

        public SessionArray(List<Session> sessionArray) {
            this.sessionArray = sessionArray;
        }
    }

    public class Session {

        @InvocableVariable(
            description='Session Record Id'
        )
        public Id sessionId;

        @InvocableVariable(
            description='Picklist value representing the size of room required'
        )
        public String roomSize;

        @InvocableVariable(
            description='Speakers for this session'
        )
        public List < Speaker > speakers;

        @InvocableVariable(
            description='Session length in minutes'
        )
        public Integer sessionLength;

        @InvocableVariable(
            description='Indicates if this session has been scheduled'
        )
        public Boolean isScheduled;

        @InvocableVariable(
            description='Session Name'
        )
        public String sessionName;

        public Session (Id sessionId, String roomSize, List < Speaker > speakers, Integer sessionLength, Boolean isScheduled, String sessionName) {
            this.sessionId = sessionId;
            this.roomSize = roomSize;
            this.speakers = speakers;
            this.sessionLength = sessionLength;
            this.isScheduled = isScheduled;
            this.sessionName = sessionName;
        }
    }

    public class Speaker {

        public Speaker (String firstName, String lastName, String email, String contactId) {
            this.firstName = firstName;
            this.lastName = lastName;
            this.email = email;
            this.contactId = contactId;
        }

        @InvocableVariable(
            description='Speaker First Name'
        )
        public String firstName;

        @InvocableVariable(
            description='Speaker Last Name'
        )
        public String lastName;

        @InvocableVariable(
            description='Speaker Email'
        )
        public String email;

        @InvocableVariable(
            description='Contact ID for the Speaker'
        )
        public String contactId;
    }

    public class Availability {
        @InvocableVariable(
            description='Start Time'
        )
        public Time startTime;

        @InvocableVariable(
            description='End Time'
        )
        public Time endTime;

        @InvocableVariable(
            description='Date'
        )
        public Date availabilityDate;
    }

    public class SessionInput {
        @InvocableVariable(
            description='Useless required variable'
        )
        public String useless;

    }

}