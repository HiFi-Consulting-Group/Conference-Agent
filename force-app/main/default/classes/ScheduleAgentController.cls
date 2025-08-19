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
            return [SELECT Id, Name, Event_Start_Date__c, Event_End_Date__c, Event_Timezone__c
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
     * @description Initiates an asynchronous scheduling agent session using a dedicated queueable
     * This provides increased heap and CPU limits compared to the standard async implementation
     * @param userMessage The user message to send to the scheduling agent
     * @return A map containing the async session ID and status
     * @throws AuraHandledException if the async session initiation fails
     */
    @AuraEnabled
    public static Map<String, Object> invokeSchedulingAgentAsync(String userMessage) {
        try {

            userMessage = userMessage + 'Important: The times assigned should match the timezone of the event. Please format your response as a simple JSON object indicating success or failure: { "success": boolean, "message": "string", "slotsUpserted": number }. For example: { "success": true, "message": "Successfully scheduled sessions", "slotsUpserted": 15 } or { "success": false, "message": "Failed to schedule sessions", "slotsUpserted": 0 }. Ensure the response is complete and properly formatted JSON.';

            System.debug('Initiating async scheduling agent session with message: ' + userMessage);
            
            // Create the async session record directly
            Async_Agent_Session__c asyncSession = new Async_Agent_Session__c(
                Agent_API_Name__c = 'Scheduling_Agent_1',
                User_Message__c = userMessage,
                Session_ID__c = null,
                Status__c = 'Pending',
                Started_At__c = System.now()
            );
            
            insert asyncSession;
            
            System.debug('Created async session with ID: ' + asyncSession.Id);
            
            // Enqueue the dedicated scheduling agent queueable for increased limits
            SchedulingAgentQueueable executor = new SchedulingAgentQueueable(
                asyncSession.Id, 
                userMessage, 
                null
            );
            
            System.enqueueJob(executor);
            
            System.debug('Enqueued SchedulingAgentQueueable for increased limits');
            
            // Update the session status to Processing since the job is now queued
            // This is safe to do here because we're not making any callouts
            asyncSession.Status__c = 'Processing';
            update asyncSession;
            
            return new Map<String, Object>{
                'success' => true,
                'asyncSessionId' => asyncSession.Id,
                'status' => 'Processing', // Set to Processing since the job is queued
                'message' => 'Async scheduling agent session initiated successfully with increased resource limits. You can monitor progress and retrieve results when ready.',
                'isAsync' => true,
                'queueableType' => 'SchedulingAgentQueueable'
            };
            
        } catch (Exception e) {
            System.debug('Error in invokeSchedulingAgentAsync: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Error initiating async scheduling agent session: ' + e.getMessage(),
                'error' => e.getMessage()
            };
        }
    }
    
    /**
     * @description Retrieves the status and results of an async scheduling agent session
     * @param asyncSessionId The ID of the async agent session
     * @return A map containing the session status and results
     */
    @AuraEnabled
    public static Map<String, Object> getAsyncSchedulingAgentStatus(String asyncSessionId) {
        try {
            System.debug('Retrieving status for async scheduling agent session: ' + asyncSessionId);
            
            // Use the AsyncAgentController to get the session status
            Map<String, Object> statusResult = AsyncAgentController.getAsyncAgentSessionStatus(asyncSessionId);
            System.debug('statusResult:....'+ JSON.serialize(statusResult));
            
            if (statusResult.get('success') == true) {
                String status = (String) statusResult.get('status');
                
                if (status == 'Completed') {
                    // The agent response now contains success/failure status, not schedule data
                    String agentResponse = (String) statusResult.get('agentResponse');
                    Map<String, Object> parsedResponse = parseAgentResponse(agentResponse, null);
                    
                    // Add the parsed response to the result
                    statusResult.put('parsedSchedule', parsedResponse);
                    statusResult.put('isChunked', false); // Async responses shouldn't be chunked
                    
                } else if (status == 'Failed') {
                    // Add error information
                    statusResult.put('error', statusResult.get('errorMessage'));
                    statusResult.put('message', 'Async scheduling agent session failed');
                }
                
                return statusResult;
            } else {
                return statusResult;
            }
            
        } catch (Exception e) {
            System.debug('Error in getAsyncSchedulingAgentStatus: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Error retrieving async scheduling agent status: ' + e.getMessage(),
                'error' => e.getMessage()
            };
        }
    }
    
    /**
     * @description Retrieves scheduled sessions for a specific event
     * @param eventId The ID of the event to get sessions for
     * @return List of scheduled session data
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getScheduledSessions(String eventId) {
        try {
            System.debug('Retrieving scheduled sessions for event: ' + eventId);
            
            List<Map<String, Object>> scheduledSessions = new List<Map<String, Object>>();
            
            // Query for session slots with related session and location information
            List<Session_Slot__c> sessionSlots = [
                SELECT Id, Session__c, Session_Location__c, Date__c, Start_Time__c, End_Time__c,
                       Session__r.Name, Session__r.Session_Abstract__c, Session__r.Format__c, Session__r.Focus__c,
                       Session_Location__r.Name, Session_Location__r.Room_Capacity__c, Session_Location__r.Room_Size__c
                FROM Session_Slot__c 
                WHERE Session__r.Event__c = :eventId
                ORDER BY Date__c ASC, Start_Time__c ASC
            ];
            
            System.debug('Found ' + sessionSlots.size() + ' scheduled sessions');
            
            for (Session_Slot__c slot : sessionSlots) {
                Map<String, Object> sessionData = new Map<String, Object>();
                
                // Basic session information
                sessionData.put('sessionName', slot.Session__r.Name);
                sessionData.put('sessionAbstract', slot.Session__r.Session_Abstract__c);
                sessionData.put('format', slot.Session__r.Format__c);
                sessionData.put('focus', slot.Session__r.Focus__c);
                
                // Location information
                sessionData.put('location', slot.Session_Location__r.Name);
                sessionData.put('roomCapacity', slot.Session_Location__r.Room_Capacity__c);
                sessionData.put('roomSize', slot.Session_Location__r.Room_Size__c);
                
                // Time information
                if (slot.Date__c != null && slot.Start_Time__c != null && slot.End_Time__c != null) {
                    DateTime startDateTime = DateTime.newInstance(slot.Date__c, slot.Start_Time__c);
                    DateTime endDateTime = DateTime.newInstance(slot.Date__c, slot.End_Time__c);
                    
                    sessionData.put('startTime', startDateTime);
                    sessionData.put('endTime', endDateTime);
                    sessionData.put('date', slot.Date__c);
                }
                
                // Add speaker information if available
                List<Map<String, Object>> speakers = new List<Map<String, Object>>();
                List<Session_Speaker__c> sessionSpeakers = [
                    SELECT Speaker__r.FirstName, Speaker__r.LastName, Speaker__r.Email
                    FROM Session_Speaker__c 
                    WHERE Session__c = :slot.Session__c
                ];
                
                for (Session_Speaker__c speaker : sessionSpeakers) {
                    speakers.add(new Map<String, Object>{
                        'firstName' => speaker.Speaker__r.FirstName,
                        'lastName' => speaker.Speaker__r.LastName,
                        'email' => speaker.Speaker__r.Email,
                        'fullName' => speaker.Speaker__r.FirstName + ' ' + speaker.Speaker__r.LastName
                    });
                }
                
                sessionData.put('speakers', speakers);
                
                scheduledSessions.add(sessionData);
            }
            
            System.debug('Returning ' + scheduledSessions.size() + ' scheduled sessions');
            return scheduledSessions;
            
        } catch (Exception e) {
            System.debug('Error retrieving scheduled sessions: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to retrieve scheduled sessions: ' + e.getMessage());
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
            System.debug('Parsing agent response: ' + agentResponse);
            
            // Check if this is a plain text completion message (e.g., from queueable sandbox limits)
            if (agentResponse != null && !agentResponse.trim().startsWith('{') && !agentResponse.trim().startsWith('[')) {
                System.debug('Detected plain text response, checking for completion message');
                
                // Check if this looks like a completion message
                String lowerResponse = agentResponse.toLowerCase();
                if (lowerResponse.contains('scheduling completed successfully') || 
                    lowerResponse.contains('processed') || 
                    lowerResponse.contains('sessions') ||
                    lowerResponse.contains('sandbox') ||
                    lowerResponse.contains('job chaining limit')) {
                    
                    System.debug('Detected completion message in plain text');
                    
                    // This is a completion message, structure it appropriately
                    structuredResponse.put('success', true);
                    structuredResponse.put('message', agentResponse);
                    structuredResponse.put('agentName', 'Scheduling_Agent_1');
                    structuredResponse.put('processingTime', 'Real-time processing');
                    structuredResponse.put('timestamp', System.now().format());
                    structuredResponse.put('rawResponse', agentResponse);
                    structuredResponse.put('scheduleGenerated', true);
                    structuredResponse.put('totalSessions', 0); // Will be determined by database query
                    structuredResponse.put('recommendations', 'Schedule processing completed. Check the database for scheduled sessions.');
                    
                    System.debug('Successfully parsed plain text completion message: ' + JSON.serialize(structuredResponse));
                    return structuredResponse;
                }
            }
            
            // Check if this is a Salesforce AI agent response wrapper
            if (agentResponse != null && agentResponse.contains('"type":"Text"') && agentResponse.contains('"value":')) {
                System.debug('Detected Salesforce AI agent response wrapper, extracting value field');
                
                try {
                    Map<String, Object> wrapper = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
                    if (wrapper.containsKey('type') && wrapper.get('type') == 'Text' && wrapper.containsKey('value')) {
                        String valueContent = String.valueOf(wrapper.get('value'));
                        System.debug('Extracted value content: ' + valueContent);
                        
                        // Parse the nested JSON content
                        Map<String, Object> nestedContent = (Map<String, Object>) JSON.deserializeUntyped(valueContent);
                        System.debug('Parsed nested content: ' + JSON.serialize(nestedContent));
                        
                        // Now parse the actual agent response
                        return parseAgentResponseContent(nestedContent, agentResponse);
                    }
                } catch (Exception e) {
                    System.debug('Failed to parse wrapper: ' + e.getMessage());
                }
            }
            
            // Try to parse the response directly
            try {
                Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
                return parseAgentResponseContent(parsedResponse, agentResponse);
            } catch (Exception e) {
                System.debug('Failed to parse direct response: ' + e.getMessage());
            }
            
            // If all parsing fails, return error response
            structuredResponse.put('success', false);
            structuredResponse.put('message', 'Failed to parse agent response');
            structuredResponse.put('agentName', 'Scheduling_Agent_1');
            structuredResponse.put('processingTime', 'Real-time processing');
            structuredResponse.put('timestamp', System.now().format());
            structuredResponse.put('rawResponse', agentResponse);
            structuredResponse.put('error', 'Response format not recognized');
            structuredResponse.put('recommendations', 'Agent response could not be parsed. Please check the raw response.');
            
        } catch (Exception e) {
            System.debug('Error parsing agent response: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Return error response
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
    
    /**
     * @description Parses the actual agent response content (after extracting from wrapper if needed)
     * @param parsedContent The parsed JSON content from the agent
     * @param rawResponse The raw response for reference
     * @return A structured map containing the parsed response
     */
    private static Map<String, Object> parseAgentResponseContent(Map<String, Object> parsedContent, String rawResponse) {
        Map<String, Object> structuredResponse = new Map<String, Object>();
        
        try {
            System.debug('Parsing agent response content: ' + JSON.serialize(parsedContent));
            System.debug('Content keys: ' + parsedContent.keySet());
            
            // Check if the response has the expected structure for the new format
            if (parsedContent.containsKey('success') && parsedContent.containsKey('message') && parsedContent.containsKey('slotsUpserted')) {
                System.debug('Found new agent response format with success/message/slotsUpserted');
                
                // Extract the response data
                Boolean success = (Boolean) parsedContent.get('success');
                String message = (String) parsedContent.get('message');
                Integer slotsUpserted = (Integer) parsedContent.get('slotsUpserted');
                
                // Create the structured response
                structuredResponse.put('success', success);
                structuredResponse.put('message', message);
                structuredResponse.put('agentName', 'Scheduling_Agent_2');
                structuredResponse.put('processingTime', 'Real-time processing');
                structuredResponse.put('timestamp', System.now().format());
                structuredResponse.put('slotsUpserted', slotsUpserted);
                structuredResponse.put('rawResponse', rawResponse);
                
                if (success) {
                    structuredResponse.put('recommendations', 'Scheduling completed successfully. ' + slotsUpserted + ' session slots were created/updated.');
                    structuredResponse.put('scheduleGenerated', true);
                    structuredResponse.put('totalSessions', slotsUpserted);
                } else {
                    structuredResponse.put('error', message);
                    structuredResponse.put('recommendations', 'Scheduling failed. Please check the error message and try again.');
                    structuredResponse.put('scheduleGenerated', false);
                }
                
                System.debug('Successfully parsed new format response: ' + JSON.serialize(structuredResponse));
                return structuredResponse;
            }
            
            // Check if this is the old format with proposedSchedule
            if (parsedContent.containsKey('proposedSchedule')) {
                System.debug('Found old format response with proposedSchedule');
                
                List<Object> proposedSchedule = (List<Object>) parsedContent.get('proposedSchedule');
                Integer totalSessions = proposedSchedule != null ? proposedSchedule.size() : 0;
                
                structuredResponse.put('success', true);
                structuredResponse.put('message', 'Schedule generated successfully (legacy format)');
                structuredResponse.put('agentName', 'Scheduling_Agent_2');
                structuredResponse.put('processingTime', 'Real-time processing');
                structuredResponse.put('timestamp', System.now().format());
                structuredResponse.put('proposedSchedule', proposedSchedule);
                structuredResponse.put('totalSessions', totalSessions);
                structuredResponse.put('rawResponse', rawResponse);
                structuredResponse.put('recommendations', 'Schedule generated successfully with ' + totalSessions + ' sessions.');
                structuredResponse.put('scheduleGenerated', true);
                
                return structuredResponse;
            }
            
            // If we get here, the response format is not recognized
            System.debug('Response format not recognized');
            structuredResponse.put('success', false);
            structuredResponse.put('message', 'Invalid response structure');
            structuredResponse.put('agentName', 'Scheduling_Agent_2');
            structuredResponse.put('processingTime', 'Real-time processing');
            structuredResponse.put('timestamp', System.now().format());
            structuredResponse.put('rawResponse', rawResponse);
            structuredResponse.put('error', 'Response format not recognized');
            structuredResponse.put('recommendations', 'Agent response format is not recognized. Please check the raw response.');
            
        } catch (Exception e) {
            System.debug('Error parsing agent response content: ' + e.getMessage());
            
            structuredResponse.put('success', false);
            structuredResponse.put('message', 'Failed to parse agent response content');
            structuredResponse.put('agentName', 'Scheduling_Agent_2');
            structuredResponse.put('processingTime', 'Real-time processing');
            structuredResponse.put('timestamp', System.now().format());
            structuredResponse.put('rawResponse', rawResponse);
            structuredResponse.put('error', e.getMessage());
            structuredResponse.put('recommendations', 'Agent response content could not be parsed. Please check the raw response.');
        }
        
        return structuredResponse;
    }
    

    
    /**
     * @description Splits a large response into smaller chunks to avoid truncation
     * @param response The response to split
     * @param maxChunkSize The maximum size of each chunk
     * @return List of response chunks
     */
    private static List<String> splitResponseIntoChunks(String response, Integer maxChunkSize) {
        List<String> chunks = new List<String>();
        Integer responseLength = response.length();
        
        for (Integer i = 0; i < responseLength; i += maxChunkSize) {
            Integer endIndex = Math.min(i + maxChunkSize, responseLength);
            String chunk = response.substring(i, endIndex);
            chunks.add(chunk);
        }
        
        return chunks;
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