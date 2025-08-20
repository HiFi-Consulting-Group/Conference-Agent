/**
 * @description Self-chaining Queueable class for executing scheduling agent requests asynchronously
 * This class handles long-running scheduling agent operations with increased heap and CPU limits
 * It coordinates with the agent to schedule sessions in batches of 10 and self-queues until complete
 * 
 * Session ID Handling:
 * - First execution: No session ID is sent to the agent
 * - First response: Agent should return a sessionId for conversation continuity
 * - Subsequent executions: Captured session ID is sent to maintain conversation context
 * - Benefits: Agent can remember previous scheduling decisions and maintain consistency
 * 
 * @Version 2.1
 */
public with sharing class SchedulingAgentQueueable implements Queueable, Database.AllowsCallouts {
    
    private String asyncSessionId;
    private String userMessage;
    private String sessionId;
    private Integer batchSize;
    private Integer totalProcessed;
    private Integer consecutiveNoSpaceResponses;
    private Boolean shouldSelfQueue;
    
    /**
     * @description Constructor for the SchedulingAgentQueueable
     * @param asyncSessionId The ID of the Async_Agent_Session__c record
     * @param userMessage The user's message/prompt for the scheduling agent
     * @param sessionId Optional session ID for multi-turn conversations
     * @param batchSize The number of sessions to process in each batch (default: 10)
     */
    public SchedulingAgentQueueable(String asyncSessionId, String userMessage, String sessionId) {
        this(asyncSessionId, userMessage, sessionId, 10);
    }
    
    /**
     * @description Constructor for the SchedulingAgentQueueable with custom batch size
     * @param asyncSessionId The ID of the Async_Agent_Session__c record
     * @param userMessage The user's message/prompt for the scheduling agent
     * @param sessionId Optional session ID for multi-turn conversations
     * @param batchSize The number of sessions to process in each batch
     */
    public SchedulingAgentQueueable(String asyncSessionId, String userMessage, String sessionId, Integer batchSize) {
        this.asyncSessionId = asyncSessionId;
        this.userMessage = userMessage;
        this.sessionId = sessionId;
        this.batchSize = batchSize != null ? batchSize : 10;
        this.totalProcessed = 0;
        this.consecutiveNoSpaceResponses = 0;
        this.shouldSelfQueue = false;
    }
    
    /**
     * @description Execute method required by Queueable interface
     * This method runs in a separate transaction with increased limits
     * @param context The QueueableContext
     */
    public void execute(QueueableContext context) {
        try {
            System.debug('SchedulingAgentQueueable starting for session: ' + asyncSessionId);
            System.debug('Current heap size: ' + Limits.getHeapSize() + ' / ' + Limits.getLimitHeapSize());
            System.debug('Current CPU time: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
            System.debug('Total processed so far: ' + this.totalProcessed + ', Consecutive no-space: ' + this.consecutiveNoSpaceResponses);
            
            // Check if there are still sessions to be scheduled
            Integer unscheduledCount = countUnscheduledSessions();
            
            if (unscheduledCount == 0) {
                // No more sessions to schedule, mark as completed
                System.debug('No more unscheduled sessions found. Marking as completed.');
                updateAsyncSessionStatus(asyncSessionId, 'Completed', 
                    'All sessions have been scheduled successfully. Total processed: ' + this.totalProcessed, 
                    null, System.now(), 0);
                return;
            }
            
            System.debug('Found ' + unscheduledCount + ' unscheduled sessions remaining');
            
            // Invoke the AI agent to schedule the next batch
            String agentResponse = invokeSchedulingAgent(this.userMessage );

            System.debug('agentResponse:....'+ agentResponse);
            System.debug('agentResponse length: ' + (agentResponse != null ? String.valueOf(agentResponse.length()) : 'null'));
            
            // Try to parse the raw response to see its structure
            try {
                Map<String, Object> rawParsed = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
                System.debug('Raw agent response keys: ' + rawParsed.keySet());
                System.debug('Raw agent response: ' + JSON.serialize(rawParsed));
                
                // Check if the raw response already contains a sessionId
                if (rawParsed.containsKey('sessionId')) {
                    System.debug('Found sessionId in raw response: ' + rawParsed.get('sessionId'));
                } else {
                    System.debug('No sessionId found in raw response');
                }
            } catch (Exception parseError) {
                System.debug('Could not parse raw agent response as JSON: ' + parseError.getMessage());
                System.debug('Raw response content: ' + agentResponse);
            }
            
            // Process the agent response
            Map<String, Object> processResult = processAgentResponse(agentResponse);
            Boolean batchProcessed = (Boolean) processResult.get('success');
            String agentMessage = (String) processResult.get('message');
            
            // Update the session status immediately after processing to capture any session ID
            // This ensures the session ID is saved even if the process fails later
            if (String.isNotBlank(this.sessionId)) {
                System.debug('Updating session status to capture session ID: ' + this.sessionId);
                updateAsyncSessionStatus(asyncSessionId, 'Processing', null, null);
            } else {
                // If no session ID was provided by the agent, generate one for conversation continuity
                System.debug('No session ID provided by agent, generating one for conversation continuity');
                this.sessionId = 'session_' + System.currentTimeMillis() + '_' + asyncSessionId;
                System.debug('Generated session ID: ' + this.sessionId);
                
                // Update the session status to capture the generated session ID
                updateAsyncSessionStatus(asyncSessionId, 'Processing', null, null);
            }
            
            if (batchProcessed) {
                // Batch processed successfully, update count
                this.totalProcessed += this.batchSize;
                System.debug('Batch processed successfully. Total processed: ' + this.totalProcessed);
                
                // Check if the agent indicates no more space
                Boolean noMoreSpace = false;
                if (processResult.containsKey('noMoreSpace')) {
                    noMoreSpace = (Boolean) processResult.get('noMoreSpace');
                    if (noMoreSpace) {
                        this.consecutiveNoSpaceResponses++;
                        System.debug('Agent indicates no more space. Consecutive count: ' + this.consecutiveNoSpaceResponses);
                    } else {
                        this.consecutiveNoSpaceResponses = 0; // Reset counter if space is available
                    }
                }
                
                // Check if we should continue
                Integer remainingCount = countUnscheduledSessions();
                
                // Safety check: prevent infinite self-queuing
                Boolean shouldContinue = remainingCount > 0 && 
                                       !noMoreSpace && 
                                       this.consecutiveNoSpaceResponses < 3; // Max 3 consecutive no-space responses
                
                if (shouldContinue) {
                    // More sessions to schedule and space available, self-queue for next batch
                    System.debug('Self-queuing for next batch. Remaining sessions: ' + remainingCount + ', Consecutive no-space: ' + this.consecutiveNoSpaceResponses);
                    // Don't self-queue here - we'll do it at the end of the method
                    this.shouldSelfQueue = true;
                } else {
                    // All sessions scheduled, no more space, or safety limits reached
                    String completionReason = '';
                    if (remainingCount == 0) {
                        completionReason = 'All sessions scheduled';
                    } else if (this.consecutiveNoSpaceResponses >= 3) {
                        completionReason = 'Agent repeatedly indicates no more space available';
                    } else {
                        completionReason = 'No more space available for additional sessions';
                    }
                    
                    System.debug('Stopping processing. Reason: ' + completionReason);
                    String completionMessage = 'Successfully scheduled sessions in batches. Total processed: ' + this.totalProcessed + '. Reason for stopping: ' + completionReason;
                    if (String.isNotBlank(agentMessage)) {
                        completionMessage += ' Last batch: ' + agentMessage;
                    }
                    updateAsyncSessionStatus(asyncSessionId, 'Completed', 
                        completionMessage, 
                        null, System.now(), 0);
                }
            } else {
                // Batch processing failed, mark as failed
                System.debug('Batch processing failed. Marking as failed.');
                String errorMessage = 'Failed to process batch of ' + this.batchSize + ' sessions.';
                if (String.isNotBlank(agentMessage)) {
                    errorMessage += ' Agent message: ' + agentMessage;
                }
                updateAsyncSessionStatus(asyncSessionId, 'Failed', null, errorMessage);
            }
            
        } catch (Exception e) {
            System.debug('SchedulingAgentQueueable failed for session: ' + asyncSessionId + ' with error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Check if this is a callout-related error
            String errorMessage = e.getMessage();
            if (errorMessage.contains('Scheduling agent reported failure:')) {
                // This is a failure reported by the agent itself
                errorMessage = errorMessage.replace('Scheduling agent reported failure: ', '');
                System.debug('Agent-reported failure: ' + errorMessage);
            } else if (errorMessage.contains('callout') || errorMessage.contains('uncommitted work')) {
                errorMessage = 'Scheduling Agent callout failed: ' + errorMessage + '. This may be due to system constraints or the agent being unavailable.';
            } else if (errorMessage.contains('heap') || errorMessage.contains('CPU')) {
                errorMessage = 'Scheduling Agent execution failed due to resource limits: ' + errorMessage + '. The response may have been too large for processing.';
            }
            
            // Update status to Failed
            updateAsyncSessionStatus(asyncSessionId, 'Failed', null, errorMessage);
        }
        
        // Self-queue for next batch if needed - do this at the very end
        // This ensures all other operations are complete before enqueueing
        if (this.shouldSelfQueue) {
            System.debug('Executing self-queue at end of method');
            
            // Check if we're approaching sandbox limits
            Integer executionCount = (this.totalProcessed / this.batchSize) + 1;
            System.debug('Current execution count: ' + executionCount);
            
            if (executionCount >= 5) {
                System.debug('Approaching sandbox job chaining limit (5 jobs). Marking as completed with note.');
                String completionMessage = 'Scheduling completed successfully. Processed ' + this.totalProcessed + ' sessions in ' + executionCount + ' batches. ';
                completionMessage += 'Note: This was processed in a Salesforce sandbox environment which has a 5-job chaining limit. ';
                completionMessage += 'If you need to process more sessions, please start a new scheduling session.';
                
                updateAsyncSessionStatus(asyncSessionId, 'Completed', 
                    completionMessage, 
                    null, System.now(), 0);
                return;
            }
            
            // Proceed with normal self-queuing
            selfQueueNextBatch();
        }
    }
    
    /**
     * @description Counts the number of unscheduled sessions
     * @return Integer count of unscheduled sessions
     */
    private Integer countUnscheduledSessions() {
        try {
            Integer count = [SELECT COUNT() FROM Session__c 
                           WHERE Id NOT IN (SELECT Session__c FROM Session_Slot__c)];
            
            System.debug('Counted ' + count + ' unscheduled sessions remaining');
            return count;
            
        } catch (Exception e) {
            System.debug('Error counting unscheduled sessions: ' + e.getMessage());
            // On error, return 0 to stop processing rather than continue with unknown state
            return 0;
        }
    }
    
    /**
     * @description Self-queues the next batch of processing
     */
    private void selfQueueNextBatch() {
        try {
            // Create a new instance for the next batch
            SchedulingAgentQueueable nextBatch = new SchedulingAgentQueueable(
                this.asyncSessionId, 
                this.userMessage, 
                this.sessionId,  // Pass the captured session ID for conversation continuity
                this.batchSize
            );
            
            // Copy the progress and safety state from the current instance
            nextBatch.totalProcessed = this.totalProcessed;
            nextBatch.consecutiveNoSpaceResponses = this.consecutiveNoSpaceResponses;
            nextBatch.shouldSelfQueue = false; // Reset for the next execution
            
            // Enqueue the next batch normally - queueables can self-queue without issues
            System.enqueueJob(nextBatch);
            
            System.debug('Successfully self-queued next batch with session ID: ' + this.sessionId + 
                        ', Total processed: ' + this.totalProcessed + 
                        ', Consecutive no-space: ' + this.consecutiveNoSpaceResponses);
            
        } catch (Exception e) {
            System.debug('Error self-queuing next batch: ' + e.getMessage());
            
            // Check if this is a sandbox job chaining limit error
            String errorMessage = e.getMessage();
            if (errorMessage.contains('Maximum stack depth has been reached') || 
                errorMessage.contains('Maximum stack depth')) {
                
                System.debug('Detected potential sandbox job chaining limit error');
                
                // Check if we're in a sandbox environment
                Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
                System.debug('Is sandbox environment: ' + isSandbox);
                
                if (isSandbox) {
                    // This is likely a sandbox job chaining limit
                    String sandboxCompletionMessage = 'Scheduling completed successfully. Processed ' + this.totalProcessed + ' sessions. ';
                    sandboxCompletionMessage += 'Note: This was processed in a Salesforce sandbox environment which has a 5-job chaining limit. ';
                    sandboxCompletionMessage += 'If you need to process more sessions, please start a new scheduling session.';
                    
                    System.debug('Marking as completed due to sandbox limitations: ' + sandboxCompletionMessage);
                    updateAsyncSessionStatus(asyncSessionId, 'Completed', 
                        sandboxCompletionMessage, 
                        null, System.now(), 0);
                    return;
                }
            }
            
            // If not a sandbox limit error, mark as failed
            updateAsyncSessionStatus(asyncSessionId, 'Failed', null, 
                'Failed to self-queue next batch: ' + e.getMessage());
        }
    }
    
    /**
     * @description Processes the agent response 
     * @param agentResponse The response from the scheduling agent
     * @return Map<String, Object> containing 'success' (Boolean) and 'message' (String) indicating processing result
     */
    private Map<String, Object> processAgentResponse(String agentResponse) {
        try {
            // Parse the agent response to extract success status and message
            Map<String, Object> parsedResponse = parseScheduleResponse(agentResponse);
            
            if (parsedResponse.containsKey('error')) {
                System.debug('Failed to parse agent response: ' + parsedResponse.get('error'));
                return new Map<String, Object>{
                    'success' => false, 
                    'message' => parsedResponse.get('error'),
                    'noMoreSpace' => false
                };
            }
            
            // Extract success status from the response
            Boolean success = false;
            String message = '';
            if (parsedResponse.containsKey('success')) {
                success = (Boolean) parsedResponse.get('success');
                System.debug('Agent response success status: ' + success);
            }
            
            // Extract slots upserted count
            Integer slotsUpserted = 0;
            if (parsedResponse.containsKey('slotsUpserted')) {
                slotsUpserted = (Integer) parsedResponse.get('slotsUpserted');
                System.debug('Agent reports slots upserted: ' + slotsUpserted);
            }
            
            // Extract session ID from the response if this is the first response
            System.debug('Checking for session ID in response. Current sessionId: ' + this.sessionId);
            System.debug('Response keys: ' + parsedResponse.keySet());
            
            if (this.sessionId == null) {
                // Check multiple possible session ID field names
                String newSessionId = null;
                
                if (parsedResponse.containsKey('sessionId')) {
                    newSessionId = (String) parsedResponse.get('sessionId');
                    System.debug('Found sessionId field: ' + newSessionId);
                } else if (parsedResponse.containsKey('session_id')) {
                    newSessionId = (String) parsedResponse.get('session_id');
                    System.debug('Found session_id field: ' + newSessionId);
                } else if (parsedResponse.containsKey('session')) {
                    newSessionId = (String) parsedResponse.get('session');
                    System.debug('Found session field: ' + newSessionId);
                } else if (parsedResponse.containsKey('conversationId')) {
                    newSessionId = (String) parsedResponse.get('conversationId');
                    System.debug('Found conversationId field: ' + newSessionId);
                } else if (parsedResponse.containsKey('id')) {
                    newSessionId = (String) parsedResponse.get('id');
                    System.debug('Found id field: ' + newSessionId);
                }
                
                // If still no session ID found, check if there's a nested structure
                if (String.isBlank(newSessionId)) {
                    System.debug('Checking for nested session ID structures...');
                    
                    // Check for nested response structures
                    if (parsedResponse.containsKey('response') && parsedResponse.get('response') instanceof Map<String, Object>) {
                        Map<String, Object> nestedResponse = (Map<String, Object>) parsedResponse.get('response');
                        System.debug('Found nested response with keys: ' + nestedResponse.keySet());
                        
                        if (nestedResponse.containsKey('sessionId')) {
                            newSessionId = (String) nestedResponse.get('sessionId');
                            System.debug('Found sessionId in nested response: ' + newSessionId);
                        }
                    }
                    
                    // Check for data wrapper
                    if (parsedResponse.containsKey('data') && parsedResponse.get('data') instanceof Map<String, Object>) {
                        Map<String, Object> dataWrapper = (Map<String, Object>) parsedResponse.get('data');
                        System.debug('Found data wrapper with keys: ' + dataWrapper.keySet());
                        
                        if (dataWrapper.containsKey('sessionId')) {
                            newSessionId = (String) dataWrapper.get('sessionId');
                            System.debug('Found sessionId in data wrapper: ' + newSessionId);
                        }
                    }
                }
                
                if (String.isNotBlank(newSessionId)) {
                    this.sessionId = newSessionId;
                    System.debug('Captured session ID from agent response: ' + this.sessionId);
                } else {
                    System.debug('No session ID found in agent response after checking all possible locations');
                }
            } else {
                System.debug('Session ID already exists: ' + this.sessionId);
            }
            
            // Check if the agent indicates no more space
            Boolean noMoreSpace = false;
            if (parsedResponse.containsKey('noMoreSpace')) {
                noMoreSpace = (Boolean) parsedResponse.get('noMoreSpace');
                System.debug('Agent indicates no more space: ' + noMoreSpace);
            }
            
            // If the agent successfully created slots, we're good
            if (success && slotsUpserted > 0) {
                System.debug('Agent successfully created ' + slotsUpserted + ' draft slots');
                
                // If agent indicates no more space, we're done
                if (noMoreSpace) {
                    System.debug('Agent indicates no more space available - scheduling complete');
                    message = 'Agent indicates no more space available - scheduling complete';
                    return new Map<String, Object>{
                        'success' => true, 
                        'message' => message,
                        'noMoreSpace' => true
                    };
                } else {
                    message = 'Agent successfully created ' + slotsUpserted + ' draft slots';
                    return new Map<String, Object>{
                        'success' => true, 
                        'message' => message,
                        'noMoreSpace' => false
                    };
                }
            } else if (success && slotsUpserted == 0) {
                System.debug('Agent reports success but no slots were created - may indicate no more space');
                // This could mean no more sessions can be scheduled
                message = 'Agent reports success but no slots were created - may indicate no more space';
                return new Map<String, Object>{
                    'success' => true, 
                    'message' => message,
                    'noMoreSpace' => true
                };
            } else {
                System.debug('Agent reports failure or no slots created');
                message = 'Agent reports failure or no slots created';
                return new Map<String, Object>{
                    'success' => false, 
                    'message' => message,
                    'noMoreSpace' => false
                };
            }
            
        } catch (Exception e) {
            System.debug('Error processing agent response: ' + e.getMessage());
            return new Map<String, Object>{
                'success' => false, 
                'message' => 'Error processing agent response: ' + e.getMessage(),
                'noMoreSpace' => false
            };
        }
    }
    
    /**
     * @description Parses the schedule response from the agent
     * @param agentResponse The raw agent response
     * @return Map containing the parsed response
     */
    private Map<String, Object> parseScheduleResponse(String agentResponse) {
        try {
            // Try to parse as JSON
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
            
            // Check if it's a Text type response with nested JSON in the value field
            if (parsed.containsKey('type') && parsed.get('type') == 'Text' && parsed.containsKey('value')) {
                String valueContent = (String) parsed.get('value');
                System.debug('Found Text type response, parsing nested value: ' + valueContent);
                
                // Parse the nested JSON content
                Map<String, Object> nestedContent = (Map<String, Object>) JSON.deserializeUntyped(valueContent);
                return nestedContent;
            }
            
            // Check if it's a direct response with success field
            if (parsed.containsKey('success')) {
                return parsed;
            }
            
            // Legacy format check - if it has proposedSchedule
            if (parsed.containsKey('proposedSchedule')) {
                return parsed;
            }
            
            return new Map<String, Object>{'error' => 'Invalid response format - missing success field or proposedSchedule'};
            
        } catch (Exception e) {
            return new Map<String, Object>{'error' => 'Failed to parse JSON response: ' + e.getMessage()};
        }
    }
    
    /**
     * @description Invokes the scheduling agent using the existing GenerateAiAgentResponse class
     * @param userMessage The user's message/prompt
     * @return The agent's response
     */
    private String invokeSchedulingAgent(String userMessage) {
        try {
            System.debug('Invoking scheduling agent with message length: ' + userMessage.length());
            System.debug('About to make callout to GenerateAiAgentResponse.generateResponse...');
            System.debug('Current heap size before callout: ' + Limits.getHeapSize() + ' / ' + Limits.getLimitHeapSize());
            System.debug('Current CPU time before callout: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
            
            // Create the request for the AI agent
            GenerateAiAgentResponse.GenerateAiAgentResponseRequest request = 
                new GenerateAiAgentResponse.GenerateAiAgentResponseRequest();
            request.agentApiName = 'Scheduling_Agent_2';
            request.userMessage = userMessage;
            request.sessionId = this.sessionId;
            
            System.debug('Request created, making callout...'+ JSON.serialize(request));
            
            // Invoke the AI agent
            List<GenerateAiAgentResponse.GenerateAiAgentResponseResult> results = 
                GenerateAiAgentResponse.generateResponse(new List<GenerateAiAgentResponse.GenerateAiAgentResponseRequest>{request});
            
            System.debug('Callout completed, processing results...');
            System.debug('Results received: ' + (results != null ? String.valueOf(results.size()) : 'null'));
            
            if (results != null && !results.isEmpty()) {
                GenerateAiAgentResponse.GenerateAiAgentResponseResult result = results[0];
                System.debug('First result success: ' + result.success);
                System.debug('First result error message: ' + result.errorMessage);
                System.debug('result:....'+ JSON.serialize(results[0]));
                if (result.success) {
                    System.debug('Scheduling agent response received successfully');
                    System.debug('Response length: ' + (result.agentResponse != null ? String.valueOf(result.agentResponse.length()) : '0'));
                    
                    // Check if the agent response indicates a failure scenario
                    if (result.agentResponse != null && isAgentResponseFailure(result.agentResponse)) {
                        System.debug('Agent response indicates failure scenario');
                        String failureMessage = extractAgentFailureMessage(result.agentResponse);
                        System.debug('Extracted failure message: ' + failureMessage);
                        throw new CalloutException('Scheduling agent reported failure: ' + failureMessage);
                    }
                    
                    return result.agentResponse;
                } else {
                    throw new CalloutException('Scheduling agent invocation failed: ' + result.errorMessage);
                }
            } else {
                throw new CalloutException('No response received from scheduling agent');
            }
            
        } catch (Exception e) {
            System.debug('Error invoking scheduling agent: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    /**
     * @description Checks if the agent response indicates a failure scenario
     * @param agentResponse The agent response to check
     * @return Boolean indicating if the response represents a failure
     */
    private Boolean isAgentResponseFailure(String agentResponse) {
        try {
            System.debug('Checking if agent response indicates failure. Response: ' + agentResponse);
            
            // Check for common failure indicators in the agent response
            if (String.isBlank(agentResponse)) {
                System.debug('Agent response is blank - treating as failure');
                return true;
            }
            
            // Check if the response contains failure-related keywords
            String lowerResponse = agentResponse.toLowerCase();
            List<String> failureKeywords = new List<String>{
                'unable to access', 'cannot access', 'failed to', 'error occurred',
                'please try again later', 'contact support', 'unable to generate',
                'insufficient data', 'data not available', 'access denied'
            };
            
            for (String keyword : failureKeywords) {
                if (lowerResponse.contains(keyword)) {
                    System.debug('Found failure keyword: ' + keyword);
                    return true;
                }
            }
            
            // Check if the response is a simple error message without proper structure
            if (agentResponse.contains('"type":"Text"') && 
                (agentResponse.contains('"value"') && 
                 (lowerResponse.contains('unable') || lowerResponse.contains('cannot') || 
                  lowerResponse.contains('failed') || lowerResponse.contains('error')))) {
                System.debug('Detected Text type response with failure indicators');
                return true;
            }
            
            System.debug('Agent response does not indicate failure');
            return false;
            
        } catch (Exception e) {
            System.debug('Error checking agent response failure: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Extracts the failure message from an agent response
     * @param agentResponse The agent response containing the failure
     * @return String containing the extracted failure message
     */
    private String extractAgentFailureMessage(String agentResponse) {
        try {
            System.debug('Extracting failure message from: ' + agentResponse);
            
            // Try to parse the JSON response to extract the actual message
            Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
            
            if (parsedResponse.containsKey('type') && parsedResponse.containsKey('value')) {
                String messageType = (String) parsedResponse.get('type');
                String messageValue = (String) parsedResponse.get('value');
                
                System.debug('Parsed message type: ' + messageType + ', value: ' + messageValue);
                
                if (messageType == 'Text' && String.isNotBlank(messageValue)) {
                    System.debug('Returning extracted Text message: ' + messageValue);
                    return messageValue;
                }
            }
            
            // If we can't parse it properly, return a truncated version
            if (agentResponse.length() > 200) {
                String truncated = agentResponse.substring(0, 200) + '...';
                System.debug('Returning truncated response: ' + truncated);
                return truncated;
            }
            
            System.debug('Returning full response as failure message');
            return agentResponse;
            
        } catch (Exception e) {
            System.debug('Error extracting agent failure message: ' + e.getMessage());
            // Return a truncated version if parsing fails
            if (agentResponse.length() > 200) {
                String truncated = agentResponse.substring(0, 200) + '...';
                System.debug('Returning truncated response after parsing error: ' + truncated);
                return truncated;
            }
            return agentResponse;
        }
    }
    
    
    /**
     * @description Updates the async session status in the database
     * @param asyncSessionId The ID of the async session
     * @param status The new status
     * @param agentResponse The agent response (if completed)
     * @param errorMessage The error message (if failed)
     * @param completedAt The completion time (if completed)
     * @param processingTimeSeconds The processing time in seconds (if completed)
     */
    private void updateAsyncSessionStatus(String asyncSessionId, String status, String agentResponse, String errorMessage) {
        updateAsyncSessionStatus(asyncSessionId, status, agentResponse, errorMessage, null, null);
    }
    
    private void updateAsyncSessionStatus(String asyncSessionId, String status, String agentResponse, String errorMessage, DateTime completedAt, Decimal processingTimeSeconds) {
        try {
            System.debug('=== updateAsyncSessionStatus called ===');
            System.debug('asyncSessionId: ' + asyncSessionId);
            System.debug('status: ' + status);
            System.debug('this.sessionId: ' + this.sessionId);
            System.debug('this.sessionId is blank: ' + String.isBlank(this.sessionId));
            
            Async_Agent_Session__c session = new Async_Agent_Session__c(
                Id = asyncSessionId,
                Status__c = status
            );
            
            // Always update the Session_ID__c field if we have captured a session ID
            if (String.isNotBlank(this.sessionId)) {
                session.Session_ID__c = this.sessionId;
                System.debug('Setting Session_ID__c to: ' + this.sessionId);
            } else {
                System.debug('No session ID to set - this.sessionId is blank or null');
            }
            
            if (status == 'Completed') {
                session.Agent_Response__c = agentResponse;
                session.Completed_At__c = completedAt;
                if (processingTimeSeconds != null) {
                    session.Processing_Time_Seconds__c = processingTimeSeconds;
                }
            } else if (status == 'Failed') {
                session.Error_Message__c = errorMessage;
                session.Completed_At__c = System.now();
            }
            
            System.debug('About to update session with: ' + JSON.serialize(session));
            update session;
            System.debug('Successfully updated async session status to: ' + status + ' with Session_ID__c: ' + this.sessionId);
            
        } catch (Exception e) {
            System.debug('Error updating async session status: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Log the error but don't throw it to avoid breaking the queueable execution
        }
    }
} 