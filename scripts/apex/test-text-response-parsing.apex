// Test script to verify Text type response parsing works correctly
// This simulates the exact scenario from the log where the agent returns a successful text response

// Mock the SchedulingAgentQueueable class for testing
public class TestSchedulingAgentQueueable {
    
    public String asyncSessionId = 'a06gK000004muATQAY';
    public String sessionId = null;
    public Integer batchSize = 10;
    public Integer consecutiveNoSpaceResponses = 0;
    public Boolean shouldSelfQueue = false;
    public Integer totalProcessed = 0;
    public String userMessage = 'Generate a proposed schedule for undefined based on available rooms and time slots. Save the proposed schedule as Session Slots marked draft. Before selecting times and locations, check the availability of the rooms and time slots. Never schedule a session in a room with a time that overlaps with another session.';
    
    // Copy the parseScheduleResponse method for testing
    private Map<String, Object> parseScheduleResponse(String agentResponse) {
        try {
            // First, check if the response is valid JSON by looking at the first character
            if (String.isBlank(agentResponse)) {
                return new Map<String, Object>{'error' => 'Empty agent response received'};
            }
            
            String trimmedResponse = agentResponse.trim();
            
            // Check if response starts with valid JSON characters
            if (!trimmedResponse.startsWith('{') && !trimmedResponse.startsWith('[')) {
                // This is likely a plain text response, not JSON
                System.debug('Agent returned plain text response instead of JSON: ' + trimmedResponse.substring(0, Math.min(100, trimmedResponse.length())));
                
                // Check if it's a common error message
                String lowerResponse = trimmedResponse.toLowerCase();
                if (lowerResponse.contains('cannot') || lowerResponse.contains('failed') || 
                    lowerResponse.contains('error') || lowerResponse.contains('unable') ||
                    lowerResponse.contains('i cannot') || lowerResponse.contains('i need') ||
                    lowerResponse.contains('i am unable')) {
                    
                    return new Map<String, Object>{
                        'success' => false,
                        'message' => 'Agent reported: ' + trimmedResponse,
                        'slotsUpserted' => 0,
                        'error' => 'Agent returned plain text error instead of JSON response'
                    };
                }
                
                // If it's not a clear error, treat it as a failure
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'Agent response format error: Expected JSON but received plain text',
                    'slotsUpserted' => 0,
                    'error' => 'Response is not valid JSON: ' + trimmedResponse.substring(0, Math.min(200, trimmedResponse.length()))
                };
            }
            
            // Try to parse as JSON
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
            
            // Check if it's a Text type response with nested JSON in the value field
            if (parsed.containsKey('type') && parsed.get('type') == 'Text' && parsed.containsKey('value')) {
                String valueContent = (String) parsed.get('value');
                System.debug('Found Text type response, parsing nested value: ' + valueContent);
                
                // Check if the value content is JSON or plain text
                String trimmedValue = valueContent.trim();
                if (trimmedValue.startsWith('{') || trimmedValue.startsWith('[')) {
                    // The value contains JSON, parse it
                    try {
                        Map<String, Object> nestedContent = (Map<String, Object>) JSON.deserializeUntyped(valueContent);
                        return nestedContent;
                    } catch (Exception jsonEx) {
                        System.debug('Failed to parse nested JSON in Text response: ' + jsonEx.getMessage());
                        // Fall through to treat as plain text
                    }
                }
                
                // The value is plain text, check if it indicates success or failure
                String lowerValue = valueContent.toLowerCase();
                System.debug('Analyzing plain text response for success indicators: ' + valueContent);
                
                if (lowerValue.contains('successfully') || lowerValue.contains('completed') || 
                    lowerValue.contains('scheduled') || lowerValue.contains('done') ||
                    lowerValue.contains('finished') || lowerValue.contains('accomplished')) {
                    
                    // Try to extract the actual number of sessions scheduled from the text
                    Integer slotsUpserted = 0;
                    if (lowerValue.contains('scheduled')) {
                        // Look for patterns like "scheduled X sessions" or "X sessions scheduled"
                        List<String> words = valueContent.split('\\s+');
                        for (Integer i = 0; i < words.size(); i++) {
                            String word = words[i].trim();
                            // Remove common punctuation
                            word = word.replaceAll('[^0-9]', '');
                            if (word.isNumeric()) {
                                Integer num = Integer.valueOf(word);
                                if (num > 0 && num <= 100) { // Reasonable range check
                                    slotsUpserted = num;
                                    break;
                                }
                            }
                        }
                    }
                    
                    // If we couldn't extract a number, default to batch size
                    if (slotsUpserted == 0) {
                        slotsUpserted = this.batchSize;
                        System.debug('Could not extract session count from text, defaulting to batch size: ' + slotsUpserted);
                    } else {
                        System.debug('Extracted session count from text: ' + slotsUpserted);
                    }
                    
                    System.debug('Returning success response for Text type with slotsUpserted: ' + slotsUpserted);
                    return new Map<String, Object>{
                        'success' => true,
                        'message' => valueContent,
                        'slotsUpserted' => slotsUpserted,
                        'responseType' => 'Text'
                    };
                } else if (lowerValue.contains('cannot') || lowerValue.contains('failed') || 
                          lowerValue.contains('error') || lowerValue.contains('unable') ||
                          lowerValue.contains('i cannot') || lowerValue.contains('i need') ||
                          lowerValue.contains('i am unable')) {
                    
                    return new Map<String, Object>{
                        'success' => false,
                        'message' => 'Agent reported: ' + valueContent,
                        'slotsUpserted' => 0,
                        'error' => 'Agent returned plain text error instead of JSON response'
                    };
                } else {
                    // Ambiguous text response, treat as informational
                    return new Map<String, Object>{
                        'success' => true,
                        'message' => valueContent,
                        'slotsUpserted' => 0,
                        'responseType' => 'Text',
                        'info' => 'Agent returned informational text response'
                    };
                }
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
            System.debug('JSON parsing failed: ' + e.getMessage());
            System.debug('Raw response preview: ' + (agentResponse != null ? agentResponse.substring(0, Math.min(200, agentResponse.length())) : 'null'));
            
            return new Map<String, Object>{
                'error' => 'Failed to parse JSON response: ' + e.getMessage(),
                'success' => false,
                'message' => 'Agent response could not be parsed as JSON',
                'slotsUpserted' => 0
            };
        }
    }
    
    // Test method
    public void testTextResponseParsing() {
        System.debug('=== Testing Text Response Parsing ===');
        
        // Test case 1: The exact response from the log
        String testResponse1 = '{"type":"Text","value":"I\'ve successfully scheduled 10 sessions in draft status based on the available rooms and time slots. If you need any modifications or further assistance, feel free to let me know!"}';
        
        System.debug('Test 1: Parsing successful scheduling response');
        Map<String, Object> result1 = parseScheduleResponse(testResponse1);
        System.debug('Result 1: ' + result1);
        
        if (result1.containsKey('success') && (Boolean) result1.get('success')) {
            System.debug('✓ Test 1 PASSED: Successfully parsed successful scheduling response');
            System.debug('  - Success: ' + result1.get('success'));
            System.debug('  - Message: ' + result1.get('message'));
            System.debug('  - Slots Upserted: ' + result1.get('slotsUpserted'));
            System.debug('  - Response Type: ' + result1.get('responseType'));
        } else {
            System.debug('✗ Test 1 FAILED: Failed to parse successful scheduling response');
            System.debug('  - Error: ' + result1.get('error'));
        }
        
        // Test case 2: Another successful response with different wording
        String testResponse2 = '{"type":"Text","value":"I have completed scheduling 5 sessions for the conference."}';
        
        System.debug('Test 2: Parsing completed scheduling response');
        Map<String, Object> result2 = parseScheduleResponse(testResponse2);
        System.debug('Result 2: ' + result2);
        
        if (result2.containsKey('success') && (Boolean) result2.get('success')) {
            System.debug('✓ Test 2 PASSED: Successfully parsed completed scheduling response');
            System.debug('  - Success: ' + result2.get('success'));
            System.debug('  - Message: ' + result2.get('message'));
            System.debug('  - Slots Upserted: ' + result2.get('slotsUpserted'));
        } else {
            System.debug('✗ Test 2 FAILED: Failed to parse completed scheduling response');
            System.debug('  - Error: ' + result2.get('error'));
        }
        
        // Test case 3: Error response
        String testResponse3 = '{"type":"Text","value":"I cannot access the scheduling system at this time."}';
        
        System.debug('Test 3: Parsing error response');
        Map<String, Object> result3 = parseScheduleResponse(testResponse3);
        System.debug('Result 3: ' + result3);
        
        if (result3.containsKey('success') && !(Boolean) result3.get('success')) {
            System.debug('✓ Test 3 PASSED: Successfully parsed error response');
            System.debug('  - Success: ' + result3.get('success'));
            System.debug('  - Message: ' + result3.get('message'));
        } else {
            System.debug('✗ Test 3 FAILED: Failed to parse error response correctly');
        }
        
        // Test case 4: Ambiguous response
        String testResponse4 = '{"type":"Text","value":"The system is processing your request."}';
        
        System.debug('Test 4: Parsing ambiguous response');
        Map<String, Object> result4 = parseScheduleResponse(testResponse4);
        System.debug('Result 4: ' + result4);
        
        if (result4.containsKey('success')) {
            System.debug('✓ Test 4 PASSED: Successfully parsed ambiguous response');
            System.debug('  - Success: ' + result4.get('success'));
            System.debug('  - Message: ' + result4.get('message'));
            System.debug('  - Info: ' + result4.get('info'));
        } else {
            System.debug('✗ Test 4 FAILED: Failed to parse ambiguous response');
        }
        
        System.debug('=== Text Response Parsing Tests Complete ===');
    }
}

// Execute the test
TestSchedulingAgentQueueable tester = new TestSchedulingAgentQueueable();
tester.testTextResponseParsing(); 