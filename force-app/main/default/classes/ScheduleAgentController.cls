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
    public static Map<String, Object> invokeSchedulingAgent(String userMessage) {
        try {
            System.debug('Invoking scheduling agent with message: ' + userMessage);
            
            // Create the request for the AI agent
            GenerateAiAgentResponse.GenerateAiAgentResponseRequest request = 
                new GenerateAiAgentResponse.GenerateAiAgentResponseRequest();
            request.agentApiName = 'Scheduling_Agent_1';
            request.userMessage = userMessage;
            request.sessionId = null;
            
            // Invoke the AI agent
            List<GenerateAiAgentResponse.GenerateAiAgentResponseResult> results = 
                GenerateAiAgentResponse.generateResponse(new List<GenerateAiAgentResponse.GenerateAiAgentResponseRequest>{request});
            
            if (results != null && !results.isEmpty()) {
                GenerateAiAgentResponse.GenerateAiAgentResponseResult result = results[0];
                
                if (result.success) {
                    System.debug('Agent response received successfully');
                    System.debug('Response length: ' + (result.agentResponse != null ? result.agentResponse.length() : 0));
                    System.debug('Response: ' + JSON.serialize(result.agentResponse));
                    
                    // Check if the response is already chunked from GenerateAiAgentResponse
                    if (result.agentResponse != null && result.agentResponse.contains('"isChunked":true')) {
                        try {
                            Map<String, Object> chunkedData = (Map<String, Object>) JSON.deserializeUntyped(result.agentResponse);
                            if (chunkedData.containsKey('isChunked') && (Boolean) chunkedData.get('isChunked')) {
                                System.debug('Response is already chunked from GenerateAiAgentResponse');
                                return new Map<String, Object>{
                                    'success' => true,
                                    'isChunked' => true,
                                    'totalChunks' => chunkedData.get('totalChunks'),
                                    'chunks' => chunkedData.get('chunks'),
                                    'totalLength' => chunkedData.get('totalLength'),
                                    'message' => chunkedData.get('message'),
                                    'agentResponse' => result.agentResponse
                                };
                            }
                        } catch (JSONException e) {
                            System.debug('Failed to parse chunked response: ' + e.getMessage());
                        }
                    }
                    
                    // If not chunked, check if we need to apply chunking ourselves
                    if (result.agentResponse != null && result.agentResponse.length() > 50000) {
                        System.debug('Response is large, applying chunking in ScheduleAgentController');
                        List<String> chunks = splitResponseIntoChunks(result.agentResponse, 50000);
                        
                        return new Map<String, Object>{
                            'success' => true,
                            'isChunked' => true,
                            'totalChunks' => chunks.size(),
                            'chunks' => chunks,
                            'totalLength' => result.agentResponse.length(),
                            'message' => 'Response chunked due to size',
                            'agentResponse' => result.agentResponse
                        };
                    }
                    
                    // Response is not chunked, return as normal
                    return new Map<String, Object>{
                        'success' => true,
                        'isChunked' => false,
                        'agentResponse' => result.agentResponse,
                        'message' => 'Schedule generated successfully'
                    };
                    
                } else {
                    System.debug('Agent invocation failed: ' + result.errorMessage);
                    return new Map<String, Object>{
                        'success' => false,
                        'message' => 'Failed to generate schedule: ' + result.errorMessage,
                        'error' => result.errorMessage
                    };
                }
            } else {
                System.debug('No results received from agent');
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'No response received from scheduling agent',
                    'error' => 'Empty response'
                };
            }
            
        } catch (Exception e) {
            System.debug('Error in invokeSchedulingAgent: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Error invoking scheduling agent: ' + e.getMessage(),
                'error' => e.getMessage()
            };
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
            System.debug('Parsing agent response with AiAgentResponseParser: ' + agentResponse);
            Map<String, Object> parsedSchedule;
            try {
                parsedSchedule = AiAgentResponseParser.parseScheduleResponse(agentResponse);
                System.debug('Parsed schedule: ' + JSON.serialize(parsedSchedule));
                System.debug('Parsed schedule keys: ' + parsedSchedule.keySet());
                System.debug('Parsed schedule contains error: ' + parsedSchedule.containsKey('error'));
                if (parsedSchedule.containsKey('error')) {
                    System.debug('Parsed schedule error: ' + parsedSchedule.get('error'));
                }
            } catch (Exception e) {
                // Parsing failed, return error response
                structuredResponse.put('success', false);
                structuredResponse.put('message', 'Failed to parse agent response: ' + e.getMessage());
                structuredResponse.put('agentName', 'Scheduling_Agent_1');
                structuredResponse.put('processingTime', 'Real-time processing');
                structuredResponse.put('timestamp', System.now().format());
                structuredResponse.put('rawResponse', agentResponse);
                structuredResponse.put('error', e.getMessage());
                structuredResponse.put('recommendations', 'Agent response could not be parsed. Please check the raw response.');
                
                System.debug('Parsing failed: ' + e.getMessage());
                return structuredResponse;
            }

            // Parsing succeeded, extract schedule fields
            Map<String, Object> extractedFields = AiAgentResponseParser.extractScheduleFields(parsedSchedule);
            
            // Check if the parsing actually succeeded or if it returned an error
            if (parsedSchedule.containsKey('error')) {
                System.debug('Parsing returned error: ' + parsedSchedule.get('error'));
                // The parsedSchedule itself contains an error, so we can't extract fields
                String errorMessage = String.valueOf(parsedSchedule.get('error'));
                String recommendation = 'Agent response could not be parsed. ';
                
                // Check if this is a truncation issue
                if (errorMessage.contains('end-of-input') || errorMessage.contains('truncated')) {
                    recommendation += 'The response appears to be truncated. This may be due to length limits. ';
                    recommendation += 'Try requesting a smaller schedule or check the raw response for completeness.';
                } else if (parsedSchedule.containsKey('recommendation')) {
                    recommendation += String.valueOf(parsedSchedule.get('recommendation'));
                } else {
                    recommendation += 'Please check the raw response for formatting issues.';
                }
                
                structuredResponse.put('success', false);
                structuredResponse.put('message', 'Failed to parse agent response: ' + errorMessage);
                structuredResponse.put('agentName', 'Scheduling_Agent_1');
                structuredResponse.put('processingTime', 'Real-time processing');
                structuredResponse.put('timestamp', System.now().format());
                structuredResponse.put('rawResponse', agentResponse);
                structuredResponse.put('error', errorMessage);
                structuredResponse.put('recommendations', recommendation);
                
                // Add additional debugging information
                if (parsedSchedule.containsKey('responseLength')) {
                    structuredResponse.put('responseLength', parsedSchedule.get('responseLength'));
                }
                if (parsedSchedule.containsKey('exceptionType')) {
                    structuredResponse.put('exceptionType', parsedSchedule.get('exceptionType'));
                }
                
                System.debug('Failed to parse agent response: ' + errorMessage);
                return structuredResponse;
            }
            
            if (extractedFields.containsKey('error')) {
                // Schedule structure is invalid
                structuredResponse.put('success', false);
                structuredResponse.put('message', 'Invalid schedule structure: ' + extractedFields.get('error'));
                structuredResponse.put('agentName', 'Scheduling_Agent_1');
                structuredResponse.put('processingTime', 'Real-time processing');
                structuredResponse.put('timestamp', System.now().format());
                structuredResponse.put('rawResponse', agentResponse);
                structuredResponse.put('error', extractedFields.get('error'));
                structuredResponse.put('recommendations', 'Schedule structure is invalid. Please check the raw response.');
                
                System.debug('Invalid schedule structure: ' + extractedFields.get('error'));
                return structuredResponse;
            }
            
            // Create a comprehensive structured response
            structuredResponse.put('success', true);
            structuredResponse.put('message', 'Schedule proposal generated successfully by Scheduling_Agent_1');
            structuredResponse.put('agentName', 'Scheduling_Agent_1');
            structuredResponse.put('processingTime', 'Real-time processing');
            structuredResponse.put('timestamp', System.now().format());
            structuredResponse.put('optimizationScore', 'AI Optimized');
            
            // Add the parsed schedule data
            structuredResponse.put('proposedSchedule', extractedFields.get('sessions'));
            structuredResponse.put('totalSessions', extractedFields.get('sessionCount'));
            structuredResponse.put('locations', extractedFields.get('locations'));
            
            // Check if this is a partial schedule
            if (extractedFields.containsKey('isPartialSchedule') && (Boolean) extractedFields.get('isPartialSchedule')) {
                structuredResponse.put('isPartialSchedule', true);
                structuredResponse.put('warning', extractedFields.get('warning'));
                structuredResponse.put('message', 'Partial schedule generated successfully by Scheduling_Agent_1 (response was truncated)');
            } else {
                structuredResponse.put('isPartialSchedule', false);
            }
            
            // Create a summary for recommendations
            Map<String, Object> summary = AiAgentResponseParser.createScheduleSummary(parsedSchedule);
            if (summary.containsKey('sessionsByLocation')) {
                structuredResponse.put('sessionsByLocation', summary.get('sessionsByLocation'));
            }
            
            // Add recommendations based on the parsed data
            String recommendations = 'Successfully parsed ' + extractedFields.get('sessionCount') + ' sessions across ' + 
                                  ((List<String>) extractedFields.get('locations')).size() + ' locations. ';
            
            if (extractedFields.containsKey('isPartialSchedule') && (Boolean) extractedFields.get('isPartialSchedule')) {
                recommendations += 'NOTE: This is a partial schedule due to response truncation. ';
                recommendations += 'Consider requesting a smaller schedule for better completeness. ';
            }
            
            recommendations += 'Schedule is optimized for minimal conflicts and optimal room utilization.';
            structuredResponse.put('recommendations', recommendations);
            
            System.debug('Successfully parsed schedule with ' + extractedFields.get('sessionCount') + ' sessions');
            System.debug('Structured response: ' + JSON.serialize(structuredResponse));
            
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