/**
 * @description Utility class for parsing AI agent responses and extracting structured data
 * @Version 1.0
 */
public with sharing class AiAgentResponseParser {
    
    /**
     * @description Parses an AI agent response and extracts the schedule data
     * @param agentResponse The raw response from the AI agent
     * @return Map containing the parsed schedule data
     */
    public static Map<String, Object> parseScheduleResponse(String agentResponse) {
        try {
            // First, try to extract clean JSON from the response
            String cleanJson = extractCleanJson(agentResponse);
            
            if (String.isNotBlank(cleanJson)) {
                // Parse the clean JSON
                Map<String, Object> scheduleData = (Map<String, Object>) JSON.deserializeUntyped(cleanJson);
                return scheduleData;
            }
            
            // If no clean JSON found, return error
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('error', 'Could not extract valid JSON from agent response');
            errorResult.put('rawResponse', agentResponse);
            errorResult.put('responseLength', agentResponse.length());
            errorResult.put('recommendation', 'Check if the AI agent response was truncated or malformed');
            return errorResult;
            
        } catch (Exception e) {
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('error', 'Failed to parse agent response: ' + e.getMessage());
            errorResult.put('rawResponse', agentResponse);
            errorResult.put('responseLength', agentResponse.length());
            errorResult.put('exceptionType', e.getTypeName());
            errorResult.put('recommendation', 'The response may be truncated or contain invalid JSON. Check the raw response for completeness.');
            return errorResult;
        }
    }
    
    /**
     * @description Attempts to extract a partial schedule from a truncated response
     * @param truncatedJson The truncated JSON string
     * @return Map containing any successfully parsed sessions or error information
     */
    public static Map<String, Object> extractPartialSchedule(String truncatedJson) {
        Map<String, Object> result = new Map<String, Object>();
        
        if (String.isBlank(truncatedJson)) {
            result.put('error', 'No content to parse');
            return result;
        }
        
        System.debug('Attempting to extract partial schedule from truncated response');
        System.debug('Content length: ' + truncatedJson.length());
        
        try {
            // Try to find complete session objects in the truncated JSON
            List<Object> partialSessions = new List<Object>();
            String currentJson = truncatedJson;
            
            // Look for complete session objects by finding matching braces
            while (currentJson.contains('"sessionName"')) {
                Integer sessionStart = currentJson.indexOf('"sessionName"');
                if (sessionStart == -1) break;
                
                // Find the start of this session object
                Integer objectStart = -1;
                for (Integer i = sessionStart; i >= 0; i--) {
                    if (currentJson.charAt(i) == '{'.charAt(0)) {
                        objectStart = i;
                        break;
                    }
                }
                
                if (objectStart == -1) {
                    // Move past this sessionName and continue
                    currentJson = currentJson.substring(sessionStart + 1);
                    continue;
                }
                
                // Find the end of this session object
                Integer braceCount = 0;
                Integer objectEnd = -1;
                
                for (Integer i = objectStart; i < currentJson.length(); i++) {
                    if (currentJson.charAt(i) == '{'.charAt(0)) {
                        braceCount++;
                    } else if (currentJson.charAt(i) == '}'.charAt(0)) {
                        braceCount--;
                        if (braceCount == 0) {
                            objectEnd = i;
                            break;
                        }
                    }
                }
                
                if (objectEnd != -1) {
                    // Extract this complete session object
                    String sessionJson = currentJson.substring(objectStart, objectEnd + 1);
                    
                    try {
                        Map<String, Object> session = (Map<String, Object>) JSON.deserializeUntyped(sessionJson);
                        if (session.containsKey('sessionName')) {
                            partialSessions.add(session);
                            System.debug('Successfully parsed partial session: ' + session.get('sessionName'));
                        }
                    } catch (Exception e) {
                        System.debug('Could not parse session object: ' + e.getMessage());
                    }
                    
                    // Move past this session
                    currentJson = currentJson.substring(objectEnd + 1);
                } else {
                    // Incomplete session object, stop here
                    break;
                }
            }
            
            if (!partialSessions.isEmpty()) {
                result.put('success', true);
                result.put('partialSessions', partialSessions);
                result.put('sessionCount', partialSessions.size());
                result.put('warning', 'Response was truncated. Only ' + partialSessions.size() + ' sessions could be parsed.');
                result.put('recommendation', 'Consider requesting a smaller schedule or check for response length limits.');
                
                // Extract unique locations from partial sessions
                Set<String> locations = new Set<String>();
                for (Object session : partialSessions) {
                    if (session instanceof Map<String, Object>) {
                        Map<String, Object> sessionMap = (Map<String, Object>) session;
                        if (sessionMap.containsKey('location')) {
                            locations.add(String.valueOf(sessionMap.get('location')));
                        }
                    }
                }
                result.put('locations', new List<String>(locations));
                
                System.debug('Successfully extracted ' + partialSessions.size() + ' partial sessions');
                return result;
            } else {
                result.put('error', 'No complete session objects could be extracted from truncated response');
                result.put('recommendation', 'The response appears to be severely truncated or malformed.');
                return result;
            }
            
        } catch (Exception e) {
            result.put('error', 'Failed to extract partial schedule: ' + e.getMessage());
            result.put('recommendation', 'Check the raw response for any salvageable content.');
            return result;
        }
    }
    
    /**
     * @description Attempts to repair a truncated JSON response by completing incomplete structures
     * @param truncatedJson The potentially truncated JSON string
     * @return Repaired JSON string or null if repair is not possible
     */
    private static String attemptJsonRepair(String truncatedJson) {
        if (String.isBlank(truncatedJson)) {
            return null;
        }
        
        System.debug('Attempting to repair potentially truncated JSON');
        System.debug('Original length: ' + truncatedJson.length());
        System.debug('Last 100 characters: ' + truncatedJson.substring(Math.max(0, truncatedJson.length() - 100)));
        
        // Check if the JSON appears to be complete
        if (truncatedJson.endsWith('"') || truncatedJson.endsWith('}') || truncatedJson.endsWith(']')) {
            System.debug('JSON appears to be complete, no repair needed');
            return truncatedJson;
        }
        
        // Try to find the last complete object or array
        String repaired = truncatedJson;
        
        // If it ends with an incomplete string, try to close it
        if (truncatedJson.endsWith('"')) {
            // Already ends with quote, might be complete
        } else if (truncatedJson.contains('"') && !truncatedJson.endsWith('"')) {
            // Ends with incomplete string, try to close it
            repaired = truncatedJson + '"';
            System.debug('Attempted to close incomplete string');
        }
        
        // If it ends with an incomplete object, try to close it
        if (repaired.endsWith('"')) {
            // Count braces to see if we need to close objects
            Integer braceCount = 0;
            Integer bracketCount = 0;
            
            for (Integer i = 0; i < repaired.length(); i++) {
                if (repaired.charAt(i) == '{'.charAt(0)) {
                    braceCount++;
                } else if (repaired.charAt(i) == '}'.charAt(0)) {
                    braceCount--;
                } else if (repaired.charAt(i) == '['.charAt(0)) {
                    bracketCount++;
                } else if (repaired.charAt(i) == ']'.charAt(0)) {
                    bracketCount--;
                }
            }
            
            // Close any unclosed braces or brackets
            while (braceCount > 0) {
                repaired += '}';
                braceCount--;
                System.debug('Added closing brace');
            }
            
            while (bracketCount > 0) {
                repaired += ']';
                bracketCount--;
                System.debug('Added closing bracket');
            }
        }
        
        // Try to validate the repaired JSON
        try {
            JSON.deserializeUntyped(repaired);
            System.debug('Successfully repaired JSON');
            System.debug('Repaired length: ' + repaired.length());
            return repaired;
        } catch (Exception e) {
            System.debug('Could not repair JSON: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Extracts clean JSON from a complex agent response string
     * @param response The raw response string
     * @return Clean JSON string or null if extraction fails
     */
    private static String extractCleanJson(String response) {
        System.debug('Extracting clean JSON from response: ' + response);
        System.debug('Response length: ' + response.length());
        
        // First, try to find if this is a Salesforce result structure
        if (response.contains('outputParameters') && response.contains('agentResponse')) {
            // Extract the agentResponse value from the nested structure
            String agentResponseStart = 'agentResponse=';
            
            Integer startIndex = response.indexOf(agentResponseStart);
            if (startIndex != -1) {
                startIndex += agentResponseStart.length();
                
                // Find the complete agentResponse object by counting braces
                Integer braceCount = 0;
                Integer jsonStart = -1;
                Integer jsonEnd = -1;
                
                System.debug('Starting brace counting from index: ' + startIndex + ', response length: ' + response.length());
                
                for (Integer i = startIndex; i < response.length(); i++) {
                    if (response.charAt(i) == '{'.charAt(0)) {
                        if (braceCount == 0) {
                            jsonStart = i;
                            System.debug('Found opening brace at index: ' + i);
                        }
                        braceCount++;
                        System.debug('Brace count increased to: ' + braceCount);
                    } else if (response.charAt(i) == '}'.charAt(0)) {
                        braceCount--;
                        System.debug('Brace count decreased to: ' + braceCount);
                        if (braceCount == 0) {
                            jsonEnd = i;
                            System.debug('Found closing brace at index: ' + i);
                            break;
                        }
                    }
                }
                
                System.debug('Final brace count: ' + braceCount + ', jsonStart: ' + jsonStart + ', jsonEnd: ' + jsonEnd);
                
                if (jsonStart != -1 && jsonEnd != -1) {
                    String agentResponse = response.substring(jsonStart, jsonEnd + 1);
                    System.debug('Extracted agentResponse length: ' + agentResponse.length());
                    System.debug('Extracted agentResponse: ' + agentResponse);
                    
                    // The agentResponse should contain the actual schedule JSON
                    // Try to parse it directly
                    try {
                        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
                        if (responseMap.containsKey('value')) {
                            String scheduleJson = (String) responseMap.get('value');
                            System.debug('Extracted schedule JSON: ' + scheduleJson);
                            System.debug('Schedule JSON length: ' + scheduleJson.length());

                            // Try to parse the schedule JSON to validate it
                            try {
                                JSON.deserializeUntyped(scheduleJson);
                                System.debug('Schedule JSON is valid and parseable');
                                return scheduleJson;
                            } catch (Exception e) {
                                System.debug('Schedule JSON is not valid: ' + e.getMessage());
                                System.debug('Schedule JSON preview (first 500 chars): ' + scheduleJson.substring(0, Math.min(500, scheduleJson.length())));
                                
                                // Check if the JSON is truncated
                                if (scheduleJson.endsWith('"') || scheduleJson.endsWith('}') || scheduleJson.endsWith(']')) {
                                    System.debug('JSON appears to be complete (ends with proper character)');
                                } else {
                                    System.debug('JSON appears to be truncated (does not end with proper character)');
                                    System.debug('Last 100 characters: ' + scheduleJson.substring(Math.max(0, scheduleJson.length() - 100)));
                                    
                                    // Try to repair the truncated JSON
                                    String repairedJson = attemptJsonRepair(scheduleJson);
                                    if (repairedJson != null) {
                                        System.debug('Successfully repaired truncated JSON');
                                        return repairedJson;
                                    }
                                    
                                    // If repair failed, try to extract partial schedule
                                    System.debug('Attempting to extract partial schedule from main schedule JSON');
                                    Map<String, Object> partialResult = extractPartialSchedule(scheduleJson);
                                    if (partialResult.containsKey('success') && (Boolean) partialResult.get('success')) {
                                        // Convert partial sessions back to JSON
                                        List<Object> partialSessions = (List<Object>) partialResult.get('partialSessions');
                                        String partialJson = JSON.serialize(partialSessions);
                                        System.debug('Successfully extracted partial schedule with ' + partialSessions.size() + ' sessions');
                                        return partialJson;
                                    }
                                }
                                
                                // The value field might contain unescaped JSON
                                // Try to extract the JSON content by finding matching braces
                                Integer innerBraceCount = 0;
                                Integer innerJsonStart = -1;
                                Integer innerJsonEnd = -1;
                                
                                for (Integer j = 0; j < scheduleJson.length(); j++) {
                                    if (scheduleJson.charAt(j) == '{'.charAt(0)) {
                                        if (innerBraceCount == 0) {
                                            innerJsonStart = j;
                                        }
                                        innerBraceCount++;
                                    } else if (scheduleJson.charAt(j) == '}'.charAt(0)) {
                                        innerBraceCount--;
                                        if (innerBraceCount == 0) {
                                            innerJsonEnd = j;
                                            break;
                                        }
                                    }
                                }
                                
                                if (innerJsonStart != -1 && innerJsonEnd != -1) {
                                    String extractedJson = scheduleJson.substring(innerJsonStart, innerJsonEnd + 1);
                                    System.debug('Extracted JSON from value field: ' + extractedJson);
                                    System.debug('Extracted JSON length: ' + extractedJson.length());
                                    
                                    try {
                                        JSON.deserializeUntyped(extractedJson);
                                        System.debug('Extracted JSON is valid');
                                        return extractedJson;
                                    } catch (Exception e2) {
                                        System.debug('Extracted JSON is still not valid: ' + e2.getMessage());
                                        System.debug('Extracted JSON preview (first 500 chars): ' + extractedJson.substring(0, Math.min(500, extractedJson.length())));
                                        
                                        // Try to repair the extracted JSON as well
                                        String repairedExtractedJson = attemptJsonRepair(extractedJson);
                                        if (repairedExtractedJson != null) {
                                            System.debug('Successfully repaired extracted JSON');
                                            return repairedExtractedJson;
                                        }
                                        
                                        // If repair failed, try to extract partial schedule
                                        System.debug('Attempting to extract partial schedule from failed JSON');
                                        Map<String, Object> partialResult = extractPartialSchedule(extractedJson);
                                        if (partialResult.containsKey('success') && (Boolean) partialResult.get('success')) {
                                            // Convert partial sessions back to JSON
                                            List<Object> partialSessions = (List<Object>) partialResult.get('partialSessions');
                                            String partialJson = JSON.serialize(partialSessions);
                                            System.debug('Successfully extracted partial schedule with ' + partialSessions.size() + ' sessions');
                                            return partialJson;
                                        }
                                    }
                                } else {
                                    System.debug('Could not find matching braces in schedule JSON');
                                }
                            }
                        } else {
                            System.debug('agentResponse does not contain "value" field');
                            System.debug('Available keys: ' + responseMap.keySet());
                        }
                    } catch (Exception e) {
                        System.debug('Could not parse agentResponse: ' + e.getMessage());
                        
                        // If we can't parse the agentResponse as JSON, it might be malformed
                        // Try to extract the value field manually by looking for "value":" pattern
                        String valuePattern = '"value":"';
                        Integer valueStart = agentResponse.indexOf(valuePattern);
                        if (valueStart != -1) {
                            valueStart += valuePattern.length();
                            
                            // Find the end of the value by looking for the next quote after the value content
                            // We need to handle the case where the value contains unescaped quotes
                            Integer valueEnd = -1;
                            Integer manualBraceCount = 0;
                            Boolean inValue = false;
                            
                            for (Integer i = valueStart; i < agentResponse.length(); i++) {
                                if (agentResponse.charAt(i) == '{'.charAt(0)) {
                                    if (!inValue) {
                                        inValue = true;
                                    }
                                    manualBraceCount++;
                                } else if (agentResponse.charAt(i) == '}'.charAt(0)) {
                                    manualBraceCount--;
                                    if (manualBraceCount == 0 && inValue) {
                                        valueEnd = i + 1;
                                        break;
                                    }
                                }
                            }
                            
                            if (valueEnd != -1) {
                                String extractedValue = agentResponse.substring(valueStart, valueEnd);
                                System.debug('Manually extracted value: ' + extractedValue);
                                System.debug('Manually extracted value length: ' + extractedValue.length());
                                
                                try {
                                    JSON.deserializeUntyped(extractedValue);
                                    System.debug('Manually extracted value is valid JSON');
                                    return extractedValue;
                                } catch (Exception e2) {
                                    System.debug('Manually extracted value is not valid JSON: ' + e2.getMessage());
                                    System.debug('Manually extracted value preview (first 500 chars): ' + extractedValue.substring(0, Math.min(500, extractedValue.length())));
                                    
                                    // Try to repair the manually extracted value
                                    String repairedValue = attemptJsonRepair(extractedValue);
                                    if (repairedValue != null) {
                                        System.debug('Successfully repaired manually extracted value');
                                        return repairedValue;
                                    }
                                    
                                    // If repair failed, try to extract partial schedule
                                    System.debug('Attempting to extract partial schedule from manually extracted value');
                                    Map<String, Object> partialResult = extractPartialSchedule(extractedValue);
                                    if (partialResult.containsKey('success') && (Boolean) partialResult.get('success')) {
                                        // Convert partial sessions back to JSON
                                        List<Object> partialSessions = (List<Object>) partialResult.get('partialSessions');
                                        String partialJson = JSON.serialize(partialSessions);
                                        System.debug('Successfully extracted partial schedule with ' + partialSessions.size() + ' sessions');
                                        return partialJson;
                                    }
                                }
                            } else {
                                System.debug('Could not find end of value field');
                            }
                        } else {
                            System.debug('Could not find "value":" pattern in agentResponse');
                        }
                    }
                } else {
                    System.debug('Could not find complete JSON structure in agentResponse');
                    if (jsonStart != -1) {
                        System.debug('Found start but no end. Start index: ' + jsonStart);
                        System.debug('Response from start index: ' + response.substring(jsonStart, Math.min(jsonStart + 200, response.length())));
                    }
                }
            } else {
                System.debug('Could not find "agentResponse=" in response');
            }
        }
        
        // If not a Salesforce result structure, try the original logic
        // Look for JSON content between curly braces
        String cleaned = response.trim();
        
        // Find the first opening brace
        Integer startBrace = cleaned.indexOf('{');
        if (startBrace == -1) {
            System.debug('No opening brace found in response');
            return null;
        }
        
        // Find the matching closing brace
        Integer braceCount = 0;
        Integer endBrace = -1;
        
        for (Integer i = startBrace; i < cleaned.length(); i++) {
            if (cleaned.charAt(i) == '{'.charAt(0)) {
                braceCount++;
            } else if (cleaned.charAt(i) == '}'.charAt(0)) {
                braceCount--;
                if (braceCount == 0) {
                    endBrace = i;
                    break;
                }
            }
        }
        
        if (endBrace == -1) {
            System.debug('No matching closing brace found');
            System.debug('Response from start brace: ' + cleaned.substring(startBrace, Math.min(startBrace + 200, cleaned.length())));
            return null;
        }
        
        // Extract the JSON content
        String jsonContent = cleaned.substring(startBrace, endBrace + 1);
        System.debug('Extracted JSON content: ' + jsonContent);
        System.debug('Extracted JSON content length: ' + jsonContent.length());
        
        // Validate that it's valid JSON
        try {
            JSON.deserializeUntyped(jsonContent);
            System.debug('Extracted content is valid JSON');
            return jsonContent;
        } catch (Exception e) {
            System.debug('Extracted content is not valid JSON: ' + e.getMessage());
            System.debug('JSON content preview (first 500 chars): ' + jsonContent.substring(0, Math.min(500, jsonContent.length())));
            
            // Try to repair the extracted content
            String repairedContent = attemptJsonRepair(jsonContent);
            if (repairedContent != null) {
                System.debug('Successfully repaired extracted content');
                return repairedContent;
            }
            
            // If repair failed, try to extract partial schedule
            System.debug('Attempting to extract partial schedule from failed JSON content');
            Map<String, Object> partialResult = extractPartialSchedule(jsonContent);
            if (partialResult.containsKey('success') && (Boolean) partialResult.get('success')) {
                // Convert partial sessions back to JSON
                List<Object> partialSessions = (List<Object>) partialResult.get('partialSessions');
                String partialJson = JSON.serialize(partialSessions);
                System.debug('Successfully extracted partial schedule with ' + partialSessions.size() + ' sessions');
                return partialJson;
            }
            
            return null;
        }
    }
    
    /**
     * @description Extracts specific fields from a parsed schedule response
     * @param scheduleData The parsed schedule data
     * @return Map with extracted fields
     */
    public static Map<String, Object> extractScheduleFields(Map<String, Object> scheduleData) {
        Map<String, Object> extracted = new Map<String, Object>();
        
        try {
            if (scheduleData.containsKey('proposedSchedule')) {
                Object scheduleObj = scheduleData.get('proposedSchedule');
                if (scheduleObj instanceof List<Object>) {
                    List<Object> sessions = (List<Object>) scheduleObj;
                    extracted.put('sessionCount', sessions.size());
                    extracted.put('sessions', sessions);
                    
                    // Extract unique locations
                    Set<String> locations = new Set<String>();
                    for (Object session : sessions) {
                        if (session instanceof Map<String, Object>) {
                            Map<String, Object> sessionMap = (Map<String, Object>) session;
                            if (sessionMap.containsKey('location')) {
                                locations.add(String.valueOf(sessionMap.get('location')));
                            }
                        }
                    }
                    extracted.put('locations', new List<String>(locations));
                    
                } else {
                    extracted.put('error', 'proposedSchedule is not a list');
                }
            } else {
                extracted.put('error', 'No proposedSchedule found in response');
            }
            
        } catch (Exception e) {
            extracted.put('error', 'Failed to extract schedule fields: ' + e.getMessage());
        }
        
        return extracted;
    }
    
    /**
     * @description Creates a simplified schedule summary from the parsed data
     * @param scheduleData The parsed schedule data
     * @return Simplified schedule summary
     */
    public static Map<String, Object> createScheduleSummary(Map<String, Object> scheduleData) {
        Map<String, Object> summary = new Map<String, Object>();
        
        try {
            Map<String, Object> extracted = extractScheduleFields(scheduleData);
            
            if (extracted.containsKey('error')) {
                summary.put('success', false);
                summary.put('error', extracted.get('error'));
                return summary;
            }
            
            summary.put('success', true);
            summary.put('totalSessions', extracted.get('sessionCount'));
            summary.put('locations', extracted.get('locations'));
            
            // Group sessions by location
            if (extracted.containsKey('sessions')) {
                List<Object> sessions = (List<Object>) extracted.get('sessions');
                Map<String, List<Object>> sessionsByLocation = new Map<String, List<Object>>();
                
                for (Object session : sessions) {
                    if (session instanceof Map<String, Object>) {
                        Map<String, Object> sessionMap = (Map<String, Object>) session;
                        String location = String.valueOf(sessionMap.get('location'));
                        
                        if (!sessionsByLocation.containsKey(location)) {
                            sessionsByLocation.put(location, new List<Object>());
                        }
                        sessionsByLocation.get(location).add(session);
                    }
                }
                
                summary.put('sessionsByLocation', sessionsByLocation);
            }
            
        } catch (Exception e) {
            summary.put('success', false);
            summary.put('error', 'Failed to create summary: ' + e.getMessage());
        }
        
        return summary;
    }
}