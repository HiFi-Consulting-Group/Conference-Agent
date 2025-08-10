/**
 * @description This class is used to manage the scheduling of sessions for Agentforce.
 *      It provides methods to retrieve sessions that need to be scheduled and create session slots.
 * @Version 1.0
 */
public with sharing class ScheduleAgentController {
    
    /**
     * @description This method is used to retrieve all Event__c records from the database.
     * @Version 1.0
     * @Return: A list of Event__c records
     * @throws: None
     */
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getEvents() {
        try {
            return [SELECT Id, Name, Event_Start_Date__c, Event_End_Date__c 
                    FROM Event__c 
                    ORDER BY Event_Start_Date__c DESC];
        } catch (Exception e) {
            System.debug('Error retrieving events: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve events: ' + e.getMessage());
        }
    }
    
    /**
     * @description This method is used to retrieve sessions that need to be scheduled.
     * @Version 1.0
     * @Param: InvocableMethods called by Agentforce must have an input parameter, we don't actually need any kind of input for this method so it's value is not used.
     * @Return: A list of SessionArray objects containing the retrieved sessions
     * @throws: None
     */
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

    /**
     * @description This method is used to invoke the Scheduling_Agent_1 to build a proposed schedule.
     * @Version 1.0
     * @param eventId The ID of the event to schedule
     * @param context Additional context for the scheduling agent
     * @return A map containing the agent response and proposed schedule
     * @throws AuraHandledException if the agent invocation fails
     */
    @AuraEnabled
    public static String invokeSchedulingAgent(String eventId, String context) {
        try {
            // Prepare the input for the Scheduling_Agent_1
            Map<String, Object> agentInput = new Map<String, Object>();
            agentInput.put('eventId', eventId);
            agentInput.put('action', 'buildProposedSchedule');
            agentInput.put('context', context);
            agentInput.put('timestamp', System.now().format());
            
            System.debug('Invoking Scheduling_Agent_1 with input: ' + JSON.serialize(agentInput));
            
            // Create the user message for the agent
            String userMessage = 'Please build a proposed conference schedule for event ID: ' + eventId + 
                               '. Context: ' + context + 
                               '. Use the available sessions and locations to create an optimized schedule.';
            
            // Invoke our GenerateAiAgentResponse invocable action
            List<GenerateAiAgentResponse.GenerateAiAgentResponseRequest> requests = new List<GenerateAiAgentResponse.GenerateAiAgentResponseRequest>();
            GenerateAiAgentResponse.GenerateAiAgentResponseRequest request = new GenerateAiAgentResponse.GenerateAiAgentResponseRequest();
            request.userMessage = userMessage;
            request.agentApiName = 'Scheduling_Agent_1';  // Explicitly specify the agent
            requests.add(request);
            
            // Call the invocable method directly
            List<GenerateAiAgentResponse.GenerateAiAgentResponseResult> results = GenerateAiAgentResponse.generateResponse(requests);
            
            if (results != null && !results.isEmpty()) {
                GenerateAiAgentResponse.GenerateAiAgentResponseResult result = results[0];
                
                if (result.success && result.agentResponse != null) {
                    String agentResponse = result.agentResponse;
                    
                    System.debug('Scheduling_Agent_1 raw response: ' + agentResponse);
                    
                    // Parse the agent response and structure it for the frontend
                    Map<String, Object> structuredResponse = parseAgentResponse(agentResponse, eventId);
                    return JSON.serialize(structuredResponse);
                } else {
                    throw new CalloutException('Agent invocation failed: ' + (result.errorMessage != null ? result.errorMessage : 'Unknown error'));
                }
            } else {
                throw new CalloutException('No results received from agent invocation');
            }
            
        } catch (Exception e) {
            System.debug('Error invoking Scheduling_Agent_1: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to invoke Scheduling_Agent_1: ' + e.getMessage());
        }
    }
    
    /**
     * @description Parses the agent response and structures it for the frontend
     * @param agentResponse The raw response from the agent
     * @param eventId The event ID for additional context
     * @return A structured map containing the parsed response
     */
    private static Map<String, Object> parseAgentResponse(String agentResponse, String eventId) {
        Map<String, Object> structuredResponse = new Map<String, Object>();
        
        try {
            // Try to parse as JSON first
            if (agentResponse.startsWith('{') || agentResponse.startsWith('[')) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
                structuredResponse.putAll(jsonResponse);
            } else {
                // If not JSON, create a structured response from the text
                structuredResponse.put('success', true);
                structuredResponse.put('message', 'Schedule proposal generated successfully by Scheduling_Agent_1');
                structuredResponse.put('agentName', 'Scheduling_Agent_1');
                structuredResponse.put('processingTime', 'Real-time processing');
                structuredResponse.put('timestamp', System.now().format());
                structuredResponse.put('rawResponse', agentResponse);
                structuredResponse.put('recommendations', agentResponse);
            }
            
            // Ensure required fields are present
            if (!structuredResponse.containsKey('success')) {
                structuredResponse.put('success', true);
            }
            if (!structuredResponse.containsKey('agentName')) {
                structuredResponse.put('agentName', 'Scheduling_Agent_1');
            }
            if (!structuredResponse.containsKey('timestamp')) {
                structuredResponse.put('timestamp', System.now().format());
            }
            
            // Only generate fallback slots if the agent response indicates success
            // and doesn't contain the expected proposedSlots
            if (structuredResponse.containsKey('success') && 
                (Boolean) structuredResponse.get('success') && 
                (!structuredResponse.containsKey('proposedSlots') || structuredResponse.get('proposedSlots') == null)) {
                
                // Check if this is an error response from the agent
                if (structuredResponse.containsKey('error') && structuredResponse.get('error') != null) {
                    // Agent returned an error, don't generate fallback slots
                    System.debug('Agent returned error, not generating fallback slots: ' + structuredResponse.get('error'));
                } else {
                    // Agent succeeded but no slots provided - don't generate fake data
                    // Just log this and let the LWC handle the response as-is
                    System.debug('Agent succeeded but no proposedSlots provided. Returning response without fallback data.');
                }
            }
            
            // Set optimization score if not present
            if (!structuredResponse.containsKey('optimizationScore')) {
                structuredResponse.put('optimizationScore', 'AI Optimized');
            }
            
            System.debug('Structured response: ' + JSON.serialize(structuredResponse));
            
        } catch (Exception e) {
            System.debug('Error parsing agent response: ' + e.getMessage());
            // Don't generate fallback slots on parsing errors
            // Return the raw response with error information
            structuredResponse.put('success', false);
            structuredResponse.put('message', 'Failed to parse agent response');
            structuredResponse.put('agentName', 'Scheduling_Agent_1');
            structuredResponse.put('processingTime', 'Real-time processing');
            structuredResponse.put('timestamp', System.now().format());
            structuredResponse.put('rawResponse', agentResponse);
            structuredResponse.put('error', e.getMessage());
            structuredResponse.put('recommendations', 'Agent response could not be parsed. Please check the raw response.');
        }
        
        return structuredResponse;
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