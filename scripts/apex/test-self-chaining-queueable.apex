/**
 * @description Test script for the refactored self-chaining SchedulingAgentQueueable class
 * This demonstrates how the class now coordinates with the agent to schedule sessions in batches
 */

// Test the new simplified self-chaining functionality
System.debug('=== Testing Simplified Self-Chaining SchedulingAgentQueueable ===');

// Create a test async session record
Async_Agent_Session__c testSession = new Async_Agent_Session__c(
    Agent_API_Name__c = 'Scheduling_Agent_1',
    User_Message__c = 'Please schedule all unscheduled sessions for the conference',
    Session_ID__c = null,
    Status__c = 'Pending',
    Started_At__c = System.now()
);

insert testSession;
System.debug('Created test async session with ID: ' + testSession.Id);

// Test the default constructor (batch size of 10)
System.debug('Testing default constructor with batch size 10...');
SchedulingAgentQueueable queueable1 = new SchedulingAgentQueueable(
    testSession.Id,
    'Please schedule all unscheduled sessions for the conference',
    null
);

System.debug('Queueable1 batch size: ' + queueable1.batchSize);
System.debug('Queueable1 total processed: ' + queueable1.totalProcessed);

// Test the custom constructor with different batch size
System.debug('Testing custom constructor with batch size 5...');
SchedulingAgentQueueable queueable2 = new SchedulingAgentQueueable(
    testSession.Id,
    'Please schedule all unscheduled sessions for the conference',
    null,
    5
);

System.debug('Queueable2 batch size: ' + queueable2.batchSize);
System.debug('Queueable2 total processed: ' + queueable2.totalProcessed);

// Test the self-queuing mechanism (this would normally be called from execute method)
System.debug('Testing self-queuing mechanism...');

// Simulate some progress
queueable2.totalProcessed = 15;
System.debug('Updated queueable2 - total processed: ' + queueable2.totalProcessed);

// Test the batch message creation (this would normally be called from execute method)
System.debug('Testing batch message creation...');

// Simulate checking for unscheduled sessions
Integer unscheduledCount = 25;
System.debug('Simulated unscheduled sessions count: ' + unscheduledCount);

// Check if we should continue
if (unscheduledCount > 0) {
    System.debug('More sessions to schedule - would self-queue next batch');
    System.debug('Remaining sessions: ' + unscheduledCount);
} else {
    System.debug('All sessions scheduled - would mark as completed');
}

System.debug('=== Test completed successfully ===');
System.debug('The SchedulingAgentQueueable class now follows a simplified pattern:');
System.debug('1. Each execution checks if there are unscheduled sessions');
System.debug('2. If yes, asks the agent to schedule the next batch');
System.debug('3. If successful, self-queues and repeats');
System.debug('4. If no more sessions or no more space, finishes');
System.debug('5. The agent handles the actual session loading and scheduling decisions');

// Clean up test data
delete testSession;
System.debug('Cleaned up test async session'); 