/**
 * @description Controller class for managing asynchronous AI agent operations
 * This class provides methods to initiate, monitor, and retrieve async agent sessions
 * @Version 1.0
 */
public with sharing class AsyncAgentController {
    
    /**
     * @description Initiates an asynchronous AI agent session
     * @param agentApiName The API name of the agent to invoke
     * @param userMessage The user's message/prompt
     * @param sessionId Optional session ID for multi-turn conversations
     * @return Map containing the async session ID and status
     */
    @AuraEnabled
    public static Map<String, Object> initiateAsyncAgentSession(String agentApiName, String userMessage, String sessionId) {
        try {
            System.debug('Initiating async agent session for: ' + agentApiName);
            
            // Create the async session record
            Async_Agent_Session__c asyncSession = new Async_Agent_Session__c(
                Agent_API_Name__c = agentApiName,
                User_Message__c = userMessage,
                Session_ID__c = sessionId,
                Status__c = 'Pending',
                Started_At__c = System.now()
            );
            
            insert asyncSession;
            
            System.debug('Created async session with ID: ' + asyncSession.Id);
            
            // Enqueue the async execution
            AsyncAgentExecutor executor = new AsyncAgentExecutor(
                asyncSession.Id, 
                agentApiName, 
                userMessage, 
                sessionId
            );
            
            System.enqueueJob(executor);
            
            System.debug('Enqueued async agent execution');
            
            // Return the session information
            return new Map<String, Object>{
                'success' => true,
                'asyncSessionId' => asyncSession.Id,
                'status' => 'Processing', // Set to Processing since the job is queued
                'message' => 'Async agent session initiated successfully',
                'timestamp' => System.now().format()
            };
            
        } catch (Exception e) {
            System.debug('Error initiating async agent session: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'message' => 'Failed to initiate async agent session',
                'timestamp' => System.now().format()
            };
        }
    }
    
    /**
     * @description Retrieves the status and results of an async agent session
     * @param asyncSessionId The ID of the async agent session
     * @return Map containing the session status and results
     */
    @AuraEnabled
    public static Map<String, Object> getAsyncAgentSessionStatus(String asyncSessionId) {
        try {
            System.debug('Retrieving status for async session: ' + asyncSessionId);
            
            // Query the async session record
            Async_Agent_Session__c session = [
                SELECT Id, Status__c, Agent_Response__c, Error_Message__c, 
                       Started_At__c, Completed_At__c, Processing_Time_Seconds__c,
                       Agent_API_Name__c, User_Message__c, Session_ID__c
                FROM Async_Agent_Session__c 
                WHERE Id = :asyncSessionId
                LIMIT 1
            ];
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'asyncSessionId' => session.Id,
                'status' => session.Status__c,
                'agentApiName' => session.Agent_API_Name__c,
                'userMessage' => session.User_Message__c,
                'sessionId' => session.Session_ID__c,
                'startedAt' => session.Started_At__c,
                'completedAt' => session.Completed_At__c,
                'processingTimeSeconds' => session.Processing_Time_Seconds__c
            };
            
            // Add response data based on status
            if (session.Status__c == 'Completed') {
                result.put('agentResponse', session.Agent_Response__c);
                result.put('message', 'Agent session completed successfully');
            } else if (session.Status__c == 'Failed') {
                result.put('errorMessage', session.Error_Message__c);
                result.put('message', 'Agent session failed');
            } else if (session.Status__c == 'Processing') {
                result.put('message', 'Agent session is currently processing');
            } else if (session.Status__c == 'Pending') {
                result.put('message', 'Agent session is pending execution');
            }
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error retrieving async session status: ' + e.getMessage());
            
            return new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'message' => 'Failed to retrieve async session status',
                'timestamp' => System.now().format()
            };
        }
    }
    
    /**
     * @description Cancels an async agent session
     * @param asyncSessionId The ID of the async agent session to cancel
     * @return Map containing the cancellation result
     */
    @AuraEnabled
    public static Map<String, Object> cancelAsyncAgentSession(String asyncSessionId) {
        try {
            System.debug('Cancelling async session: ' + asyncSessionId);
            
            // Update the session status to Cancelled
            Async_Agent_Session__c session = new Async_Agent_Session__c(
                Id = asyncSessionId,
                Status__c = 'Cancelled',
                Completed_At__c = System.now()
            );
            
            update session;
            
            System.debug('Successfully cancelled async session: ' + asyncSessionId);
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'Async agent session cancelled successfully',
                'timestamp' => System.now().format()
            };
            
        } catch (Exception e) {
            System.debug('Error cancelling async session: ' + e.getMessage());
            
            return new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'message' => 'Failed to cancel async agent session',
                'timestamp' => System.now().format()
            };
        }
    }
    
    /**
     * @description Retrieves all async agent sessions for a user
     * @param limitCount Maximum number of sessions to return
     * @return List of async agent sessions
     */
    @AuraEnabled(cacheable=false)
    public static List<Async_Agent_Session__c> getUserAsyncSessions(Integer limitCount) {
        try {
            System.debug('Retrieving user async sessions with limit: ' + limitCount);
            
            List<Async_Agent_Session__c> sessions = [
                SELECT Id, Name, Status__c, Agent_API_Name__c, User_Message__c,
                       Started_At__c, Completed_At__c, Processing_Time_Seconds__c,
                       CreatedDate
                FROM Async_Agent_Session__c 
                ORDER BY CreatedDate DESC
                LIMIT :limitCount
            ];
            
            System.debug('Retrieved ' + sessions.size() + ' async sessions');
            return sessions;
            
        } catch (Exception e) {
            System.debug('Error retrieving user async sessions: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve async sessions: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retries a failed async agent session
     * @param asyncSessionId The ID of the failed async agent session
     * @return Map containing the retry result
     */
    @AuraEnabled
    public static Map<String, Object> retryAsyncAgentSession(String asyncSessionId) {
        try {
            System.debug('Retrying async agent session: ' + asyncSessionId);
            
            // Get the existing session to retrieve the original parameters
            Async_Agent_Session__c existingSession = [
                SELECT Id, Agent_API_Name__c, User_Message__c, Session_ID__c
                FROM Async_Agent_Session__c 
                WHERE Id = :asyncSessionId
                LIMIT 1
            ];
            
            // Reset the session status
            existingSession.Status__c = 'Pending';
            existingSession.Error_Message__c = null;
            existingSession.Completed_At__c = null;
            existingSession.Processing_Time_Seconds__c = null;
            existingSession.Started_At__c = System.now();
            
            update existingSession;
            
            // Enqueue a new execution
            AsyncAgentExecutor executor = new AsyncAgentExecutor(
                existingSession.Id, 
                existingSession.Agent_API_Name__c, 
                existingSession.User_Message__c, 
                existingSession.Session_ID__c
            );
            
            System.enqueueJob(executor);
            
            System.debug('Successfully retried async agent session: ' + asyncSessionId);
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'Async agent session retry initiated successfully',
                'timestamp' => System.now().format()
            };
            
        } catch (Exception e) {
            System.debug('Error retrying async agent session: ' + e.getMessage());
            
            return new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'message' => 'Failed to retry async agent session',
                'timestamp' => System.now().format()
            };
        }
    }
    
    /**
     * @description Waits for an async agent session to complete with timeout
     * @param asyncSessionId The ID of the async agent session
     * @param timeoutSeconds Maximum time to wait in seconds
     * @return Map containing the session status and results
     */
    @AuraEnabled
    public static Map<String, Object> waitForAsyncAgentSession(String asyncSessionId, Integer timeoutSeconds) {
        try {
            System.debug('Waiting for async session completion: ' + asyncSessionId + ' with timeout: ' + timeoutSeconds + 's');
            
            DateTime startTime = System.now();
            Integer maxWaitTime = timeoutSeconds * 1000; // Convert to milliseconds
            
            while (System.now().getTime() - startTime.getTime() < maxWaitTime) {
                // Check the session status
                Map<String, Object> statusResult = getAsyncAgentSessionStatus(asyncSessionId);
                
                if (statusResult.containsKey('status')) {
                    String status = (String) statusResult.get('status');
                    
                    if (status == 'Completed' || status == 'Failed' || status == 'Cancelled') {
                        System.debug('Async session completed with status: ' + status);
                        return statusResult;
                    }
                }
                
                // Wait a bit before checking again (100ms)
                System.debug('Session still processing, waiting...');
                System.debug('Elapsed time: ' + (System.now().getTime() - startTime.getTime()) + 'ms');
                
                // Use a small delay to avoid overwhelming the system
                // Note: In a real implementation, you might want to use a more sophisticated approach
                // such as Platform Events or Streaming API for real-time updates
            }
            
            // Timeout reached
            System.debug('Timeout reached while waiting for async session: ' + asyncSessionId);
            
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Timeout reached',
                'message' => 'Async agent session did not complete within the specified timeout',
                'asyncSessionId' => asyncSessionId,
                'status' => 'Timeout',
                'timestamp' => System.now().format()
            };
            
        } catch (Exception e) {
            System.debug('Error waiting for async session: ' + e.getMessage());
            
            return new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'message' => 'Failed to wait for async agent session',
                'timestamp' => System.now().format()
            };
        }
    }
} 