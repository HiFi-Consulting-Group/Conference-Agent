// Simple test of async agent functionality without callouts
System.debug('Testing async agent functionality (simple version)...');

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
    
    // Test 3: List user async sessions
    System.debug('=== Test 3: Listing user async sessions ===');
    List<Async_Agent_Session__c> sessions = AsyncAgentController.getUserAsyncSessions(10);
    System.debug('User sessions: ' + sessions.size());
    
} else {
    System.debug('Failed to create async session: ' + asyncResult.get('error'));
}

System.debug('Simple async agent test completed.'); 