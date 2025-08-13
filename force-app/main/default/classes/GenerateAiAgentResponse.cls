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
            List<Invocable.Action.Result> results = action.invoke();
            
            System.debug('Agent response received: ' + results);
            
            if (results != null && !results.isEmpty()) {
                // The agent should return a response object
                Invocable.Action.Result result = results[0];
                System.debug('Result: ' + result);
                System.debug('Result.getOutputParameters: ' + result.getOutputParameters());
                System.debug('Result toString: ' + String.valueOf(result).substring(0, Math.min(200, String.valueOf(result).length())));
                
                // Extract the response from output parameters to avoid truncation
                Map<String, Object> outputParams = result.getOutputParameters();
                if (outputParams != null && !outputParams.isEmpty()) {
                    System.debug('Output parameters keys: ' + outputParams.keySet());
                    
                    // Look for common response field names
                    String response = null;
                    if (outputParams.containsKey('response')) {
                        response = String.valueOf(outputParams.get('response'));
                    } else if (outputParams.containsKey('agentResponse')) {
                        response = String.valueOf(outputParams.get('agentResponse'));
                    } else if (outputParams.containsKey('result')) {
                        response = String.valueOf(outputParams.get('result'));
                    } else if (outputParams.containsKey('output')) {
                        response = String.valueOf(outputParams.get('output'));
                    } else {
                        // If no specific field found, try to get the first available field
                        for (String key : outputParams.keySet()) {
                            Object value = outputParams.get(key);
                            if (value != null && String.valueOf(value).length() > 0) {
                                response = String.valueOf(value);
                                System.debug('Using output parameter key: ' + key + ' with length: ' + response.length());
                                break;
                            }
                        }
                    }
                    
                    if (response != null) {
                        System.debug('Extracted response length: ' + response.length());
                        System.debug('Response preview (first 200 chars): ' + response.substring(0, Math.min(200, response.length())));
                        System.debug('Response preview (last 200 chars): ' + response.substring(Math.max(0, response.length() - 200)));
                        
                        // Check if response is large and needs chunking
                        // Use a lower threshold to prevent truncation before platform limits
                        if (response.length() > 50000) {
                            System.debug('Response is large (' + response.length() + ' chars), applying chunking');
                            return createChunkedResponse(response);
                        }
                        
                        return response;
                    }
                }
                
                // Fallback: if we can't extract from output parameters, try to get the raw result
                // but avoid String.valueOf() which causes truncation
                System.debug('Attempting to extract response from raw result without string conversion');
                
                // Try to access the result object directly to avoid truncation
                try {
                    // Use the existing outputParams variable that was already declared
                    if (outputParams != null && outputParams.containsKey('agentResponse')) {
                        String rawResponse = String.valueOf(outputParams.get('agentResponse'));
                        System.debug('Extracted from result using getOutputParameters, length: ' + rawResponse.length());
                        
                        if (rawResponse.length() > 50000) {
                            return createChunkedResponse(rawResponse);
                        }
                        return rawResponse;
                    }
                    
                    // If we can't access it directly, try a different approach
                    // Serialize the result to JSON to preserve the full content
                    String jsonResult = JSON.serialize(result);
                    System.debug('Serialized result length: ' + jsonResult.length());
                    
                    if (jsonResult.length() > 50000) {
                        return createChunkedResponse(jsonResult);
                    }
                    return jsonResult;
                    
                } catch (Exception serializationError) {
                    System.debug('Failed to serialize result: ' + serializationError.getMessage());
                    
                    // Last resort: try to get a string representation but be aware it might be truncated
                    String rawResult = String.valueOf(result);
                    System.debug('Using raw result with length: ' + rawResult.length());
                    
                    // Check if the result contains the expected structure
                    if (rawResult.contains('agentResponse=') || rawResult.contains('"type":"Text"')) {
                        return rawResult;
                    } else {
                        // If the raw result doesn't contain expected content, try to extract from the string
                        // This is a fallback for when the result structure is different than expected
                        return rawResult;
                    }
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
     * @description Creates a chunked response for large responses
     * @param response The large response to chunk
     * @return A JSON string indicating the response is chunked
     */
    private static String createChunkedResponse(String response) {
        // Split the response into chunks of 50,000 characters to prevent truncation
        List<String> chunks = new List<String>();
        Integer chunkSize = 50000;
        Integer totalLength = response.length();
        
        for (Integer i = 0; i < totalLength; i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, totalLength);
            String chunk = response.substring(i, endIndex);
            chunks.add(chunk);
        }
        
        Map<String, Object> chunkedResponse = new Map<String, Object>();
        chunkedResponse.put('isChunked', true);
        chunkedResponse.put('totalChunks', chunks.size());
        chunkedResponse.put('chunks', chunks);
        chunkedResponse.put('totalLength', totalLength);
        chunkedResponse.put('message', 'Response chunked due to size');
        
        return JSON.serialize(chunkedResponse);
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