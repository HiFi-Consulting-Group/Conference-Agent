// Test the scheduling agent functionality with a shorter response
System.debug('Testing scheduling agent with shorter response...');

// Test the AI agent response parser with a shorter sample response
String sampleResponse = 'Result:[action=Action:[apiVersion=null, invocations=({action=generateResponse, timestamp=8/10/2025, 4:15 PM, userMessage=Please build a proposed conference schedule for event ID: a01gK000003EcrhQAC. Context: {\"selectedOption\":\"new\",\"timestamp\":\"2025-08-10T23:15:22.609Z\"}. Use the available sessions and locations to create an optimized schedule. Return the schedule in parsable JSON without any HTML tags or formatting. Do not escape quotes or add new line characters.}), invokeFromLightningComponent=false, name=Scheduling_Agent_1, namespace=null, type=generateAiAgentResponse], errors=(), invocationParameters=(already output), outputParameters={agentResponse={"type":"Text","value":"{\"schedule\": [{\"sessionName\": \"Test Session 1\",\"speakers\": [\"Test Speaker 1\"],\"location\": \"Test Room 1\",\"startTime\": \"2025-08-11T09:00:00Z\",\"endTime\": \"2025-08-11T09:45:00Z\"},{\"sessionName\": \"Test Session 2\",\"speakers\": [\"Test Speaker 2\"],\"location\": \"Test Room 2\",\"startTime\": \"2025-08-11T10:00:00Z\",\"endTime\": \"2025-08-11T10:45:00Z\"}]}"}, sessionId=test-session-id}, success=true]';

System.debug('Testing with shorter sample response: ' + sampleResponse);

// Test the parsing
Map<String, Object> parsedResult = AiAgentResponseParser.parseScheduleResponse(sampleResponse);
System.debug('Parsed result: ' + JSON.serialize(parsedResult));

System.debug('Test completed.'); 