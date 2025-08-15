/**
 * @description Queueable class for executing AI agent requests asynchronously
 * This class handles long-running AI agent operations without blocking the UI
 * @Version 1.0
 */
public with sharing class AsyncAgentExecutor implements Queueable, Database.AllowsCallouts {
    
    private String asyncSessionId;
    private String agentApiName;
    private String userMessage;
    private String sessionId;
    
    /**
     * @description Constructor for the AsyncAgentExecutor
     * @param asyncSessionId The ID of the Async_Agent_Session__c record
     * @param agentApiName The API name of the agent to invoke
     * @param userMessage The user's message/prompt
     * @param sessionId Optional session ID for multi-turn conversations
     */
    public AsyncAgentExecutor(String asyncSessionId, String agentApiName, String userMessage, String sessionId) {
        this.asyncSessionId = asyncSessionId;
        this.agentApiName = agentApiName;
        this.userMessage = userMessage;
        this.sessionId = sessionId;
    }
    
    /**
     * @description Execute method required by Queueable interface
     * @param context The QueueableContext
     */
    public void execute(QueueableContext context) {
        try {
            System.debug('AsyncAgentExecutor starting for session: ' + asyncSessionId);
            
            // Record start time
            DateTime startTime = System.now();
            
            // Invoke the AI agent using the existing GenerateAiAgentResponse class
            String agentResponse = invokeAgent(agentApiName, userMessage, sessionId);
            
            // Record completion time and calculate processing time
            DateTime endTime = System.now();
            Decimal processingTimeSeconds = (endTime.getTime() - startTime.getTime()) / 1000.0;
            
            // Update status to Completed - do this after the callout
            updateAsyncSessionStatus(asyncSessionId, 'Completed', agentResponse, null, endTime, processingTimeSeconds);
            
            System.debug('AsyncAgentExecutor completed successfully for session: ' + asyncSessionId);
            
        } catch (Exception e) {
            System.debug('AsyncAgentExecutor failed for session: ' + asyncSessionId + ' with error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Check if this is a callout-related error
            String errorMessage = e.getMessage();
            if (errorMessage.contains('callout') || errorMessage.contains('uncommitted work')) {
                errorMessage = 'AI Agent callout failed: ' + errorMessage + '. This may be due to system constraints or the agent being unavailable.';
            }
            
            // Update status to Failed - do this after the callout
            updateAsyncSessionStatus(asyncSessionId, 'Failed', null, errorMessage);
        }
    }
    
    /**
     * @description Invokes the AI agent using the existing GenerateAiAgentResponse class
     * @param agentApiName The API name of the agent to invoke
     * @param userMessage The user's message/prompt
     * @param sessionId Optional session ID for multi-turn conversations
     * @return The agent's response
     */
    private String invokeAgent(String agentApiName, String userMessage, String sessionId) {
        try {
            // Create the request for the AI agent
            GenerateAiAgentResponse.GenerateAiAgentResponseRequest request = 
                new GenerateAiAgentResponse.GenerateAiAgentResponseRequest();
            request.agentApiName = agentApiName;
            request.userMessage = userMessage;
            request.sessionId = sessionId;
            
            // Invoke the AI agent
            List<GenerateAiAgentResponse.GenerateAiAgentResponseResult> results = 
                GenerateAiAgentResponse.generateResponse(new List<GenerateAiAgentResponse.GenerateAiAgentResponseRequest>{request});
            
            if (results != null && !results.isEmpty()) {
                GenerateAiAgentResponse.GenerateAiAgentResponseResult result = results[0];
                
                if (result.success) {
                    return result.agentResponse;
                } else {
                    throw new CalloutException('Agent invocation failed: ' + result.errorMessage);
                }
            } else {
                throw new CalloutException('No response received from agent: ' + agentApiName);
            }
            
        } catch (Exception e) {
            System.debug('Error invoking agent ' + agentApiName + ': ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * @description Updates the status of an async agent session
     * @param sessionId The ID of the Async_Agent_Session__c record
     * @param status The new status
     * @param agentResponse The agent response (if completed)
     * @param errorMessage The error message (if failed)
     * @param completedAt The completion time (optional)
     * @param processingTimeSeconds The processing time in seconds (optional)
     */
    private void updateAsyncSessionStatus(String sessionId, String status, String agentResponse, String errorMessage) {
        updateAsyncSessionStatus(sessionId, status, agentResponse, errorMessage, null, null);
    }
    
    /**
     * @description Updates the status of an async agent session with completion details
     * @param sessionId The ID of the Async_Agent_Session__c record
     * @param status The new status
     * @param agentResponse The agent response (if failed)
     * @param errorMessage The error message (if failed)
     * @param completedAt The completion time (optional)
     * @param processingTimeSeconds The processing time in seconds (optional)
     */
    private void updateAsyncSessionStatus(String sessionId, String status, String agentResponse, String errorMessage, 
                                       DateTime completedAt, Decimal processingTimeSeconds) {
        try {
            Async_Agent_Session__c session = new Async_Agent_Session__c(
                Id = sessionId,
                Status__c = status
            );
            
            if (status == 'Completed') {
                session.Agent_Response__c = agentResponse;
                session.Completed_At__c = completedAt;
                session.Processing_Time_Seconds__c = processingTimeSeconds;
            } else if (status == 'Failed') {
                session.Error_Message__c = errorMessage;
                session.Completed_At__c = System.now();
            }
            
            update session;
            
        } catch (Exception e) {
            System.debug('Failed to update async session status: ' + e.getMessage());
            // Don't throw here as it would cause the queueable to fail
        }
    }
} 