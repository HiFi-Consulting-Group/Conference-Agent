// Test the scheduling agent functionality
System.debug('Testing scheduling agent...');

// Test the AI agent response parser with a sample response
String sampleResponse = 'Result:[action=Action:[apiVersion=null, invocations=({action=generateResponse, timestamp=8/10/2025, 4:06 PM, userMessage=Please build a proposed conference schedule for event ID: a01gK000003EcrhQAC. Context: {\"selectedOption\":\"new\",\"timestamp\":\"2025-08-10T23:06:53.944Z\"}. Use the available sessions and locations to create an optimized schedule. Return the schedule in parsable JSON without any HTML tags or formatting. Do not escape quotes or add new line characters.}), invokeFromLightningComponent=false, name=Scheduling_Agent_1, namespace=null, type=generateAiAgentResponse], errors=(), invocationParameters=(already output), outputParameters={agentResponse={\"type\":\"Text\",\"value\":\"{\\\"schedule\\\": [{\\\"sessionName\\\": \\\"Test Session\\\",\\\"speakers\\\": [\\\"Test Speaker\\\"],\\\"location\\\": \\\"Test Room\\\",\\\"startTime\\\": \\\"2025-08-11T09:00:00Z\\\",\\\"endTime\\\": \\\"2025-08-11T09:45:00Z\\\"}]}\"}, sessionId=1b74da47-e3a9-4103-80e9-c819df540309}, success=true]';

System.debug('Testing with sample response: ' + sampleResponse);

// Test the parsing
Map<String, Object> parsedResult = AiAgentResponseParser.parseScheduleResponse(sampleResponse);
System.debug('Parsed result: ' + JSON.serialize(parsedResult));

System.debug('Test completed.'); 