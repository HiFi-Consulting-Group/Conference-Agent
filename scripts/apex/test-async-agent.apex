// Test the async agent functionality
System.debug('Testing async agent functionality...');

// Test 1: Create an async agent session
System.debug('=== Test 1: Creating async agent session ===');
Map<String, Object> asyncResult = AsyncAgentController.initiateAsyncAgentSession(
    'Scheduling_Agent_1',
    'Generate a proposed schedule for the conference with available rooms and time slots.',
    'test-session-123'
);

System.debug('Async session creation result: ' + JSON.serialize(asyncResult));

if (asyncResult.get('success') == true) {
    String asyncSessionId = (String) asyncResult.get('asyncSessionId');
    System.debug('Async session created with ID: ' + asyncSessionId);
    
    // Test 2: Check the status of the async session
    System.debug('=== Test 2: Checking async session status ===');
    Map<String, Object> statusResult = AsyncAgentController.getAsyncAgentSessionStatus(asyncSessionId);
    System.debug('Status check result: ' + JSON.serialize(statusResult));
    
    // Test 3: Wait for completion (with a short timeout for testing)
    System.debug('=== Test 3: Waiting for async session completion ===');
    Map<String, Object> waitResult = AsyncAgentController.waitForAsyncAgentSession(asyncSessionId, 10); // 10 second timeout
    System.debug('Wait result: ' + JSON.serialize(waitResult));
    
    // Test 4: Check final status
    System.debug('=== Test 4: Final status check ===');
    Map<String, Object> finalStatus = AsyncAgentController.getAsyncAgentSessionStatus(asyncSessionId);
    System.debug('Final status: ' + JSON.serialize(finalStatus));
    
} else {
    System.debug('Failed to create async session: ' + asyncResult.get('error'));
}

System.debug('Async agent test completed.'); 