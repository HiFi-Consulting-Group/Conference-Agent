/**
 * @description Custom invocable action class for generating AI agent responses
 * This class implements the Invocable.Action pattern for Agentforce agents
 * @Version 1.0
 */
public with sharing class GenerateAiAgentResponse {
    
    @InvocableMethod(
        label='Generate AI Agent Response'
        description='Invokes an AI agent to generate a response based on user input'
        category='AI Agent'
    )
    public static List<GenerateAiAgentResponseResult> generateResponse(List<GenerateAiAgentResponseRequest> requests) {
        List<GenerateAiAgentResponseResult> results = new List<GenerateAiAgentResponseResult>();
        
        for (GenerateAiAgentResponseRequest request : requests) {
            GenerateAiAgentResponseResult result = new GenerateAiAgentResponseResult();
            
            try {
                // Validate required parameters
                if (String.isBlank(request.agentApiName)) {
                    throw new IllegalArgumentException('Agent API Name is required');
                }
                
                // Invoke the specified agent generically
                String agentResponse = invokeAgent(request.agentApiName, request.userMessage, request.sessionId);
                result.agentResponse = agentResponse;
                result.success = true;
                result.errorMessage = null;
                
            } catch (Exception e) {
                result.agentResponse = null;
                result.success = false;
                result.errorMessage = e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * @description Generic method to invoke any AI agent
     * @param agentApiName The API name of the agent to invoke
     * @param userMessage The user's message/prompt
     * @param sessionId Optional session ID for multi-turn conversations
     * @return The agent's response
     */
    private static String invokeAgent(String agentApiName, String userMessage, String sessionId) {
        try {
            // Invoke the agent using the Invocable.Action API
            // This assumes the agent is configured as an invocable action in Setup
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse', 
                agentApiName  
            );
            
            // Set the input parameters for the agent
            action.setInvocationParameter('userMessage', userMessage);
            if (sessionId != null) {
                action.setInvocationParameter('sessionId', sessionId);
            }
            
            // Add any additional context that might be useful for scheduling
            action.setInvocationParameter('timestamp', System.now().format());
            action.setInvocationParameter('action', 'generateResponse');
            
            System.debug('Invoking agent: ' + agentApiName + ' with message: ' + userMessage);
            
            // Execute the agent
            List<Object> results = action.invoke();
            
            System.debug('Agent response received: ' + results);
            
            if (results != null && !results.isEmpty()) {
                // The agent should return a response object
                Object result = results[0];
                
                // Convert the result to a string response
                if (result instanceof String) {
                    return (String) result;
                } else if (result instanceof Map<String, Object>) {
                    // If it's a map, serialize it to JSON
                    return JSON.serialize(result);
                } else {
                    // For any other type, convert to string
                    return String.valueOf(result);
                }
            } else {
                throw new CalloutException('No response received from agent: ' + agentApiName);
            }
            
        } catch (Exception e) {
            System.debug('Error invoking agent ' + agentApiName + ': ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // If the agent invocation fails, provide a helpful error message
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('error', 'Failed to invoke ' + agentApiName);
            errorResponse.put('message', e.getMessage());
            errorResponse.put('timestamp', System.now().format());
            errorResponse.put('agentName', agentApiName);
            
            return JSON.serialize(errorResponse);
        }
    }
    
    /**
     * @description Input parameters for the GenerateAiAgentResponse invocable action
     */
    public class GenerateAiAgentResponseRequest {
        @InvocableVariable(
            label='User Message'
            description='The message or prompt to send to the AI agent'
            required=true
        )
        public String userMessage;
        
        @InvocableVariable(
            label='Session ID'
            description='Optional session ID for multi-turn conversations'
            required=false
        )
        public String sessionId;
        
        @InvocableVariable(
            label='Agent API Name'
            description='The API name of the agent to invoke'
            required=false
        )
        public String agentApiName;
    }
    
    /**
     * @description Output parameters for the GenerateAiAgentResponse invocable action
     */
    public class GenerateAiAgentResponseResult {
        @InvocableVariable(
            label='Agent Response'
            description='The response generated by the AI agent'
        )
        public String agentResponse;
        
        @InvocableVariable(
            label='Success'
            description='Whether the agent invocation was successful'
        )
        public Boolean success;
        
        @InvocableVariable(
            label='Error Message'
            description='Error message if the agent invocation failed'
        )
        public String errorMessage;
    }
} 