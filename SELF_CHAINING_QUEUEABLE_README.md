# Self-Chaining SchedulingAgentQueueable

## Overview

The `SchedulingAgentQueueable` class has been refactored to implement a simplified self-chaining pattern that coordinates with the AI agent to schedule conference sessions in batches. The agent handles the actual session loading and scheduling decisions, while the queueable coordinates the process and self-queues until completion.

## Key Features

### 1. **Simplified Self-Chaining Architecture**
- Automatically processes sessions in configurable batches (default: 10 sessions per batch)
- Self-queues for the next batch when more unscheduled sessions exist
- Continues processing until all sessions are scheduled or no more space is available
- Minimal state management - relies on the agent for session decisions

### 2. **Agent-Driven Processing**
- The AI agent handles session loading and scheduling decisions
- Queueable simply asks the agent to schedule the next batch
- Agent indicates when no more space is available
- Cleaner separation of concerns

### 3. **Progress Tracking**
- Counts unscheduled sessions before each batch
- Tracks total sessions processed across batches
- Provides detailed logging for monitoring and debugging
- Simple progress state management

### 4. **Resource Management**
- Runs with increased heap and CPU limits (Queueable context)
- Processes sessions in manageable chunks
- Avoids hitting Salesforce governor limits
- Efficient memory usage through batch processing

## How It Works

### 1. **Initialization**
```apex
SchedulingAgentQueueable queueable = new SchedulingAgentQueueable(
    asyncSessionId,    // ID of the Async_Agent_Session__c record
    userMessage,       // User's scheduling request
    sessionId,         // Optional session ID for multi-turn conversations
    10                 // Optional: custom batch size (default: 10)
);
```

### 2. **Execution Flow**
1. **Check Status**: Counts unscheduled sessions remaining
2. **Request Batch**: Asks the agent to schedule the next batch
3. **Process Response**: Handles agent response and creates session slots
4. **Self-Queue**: If more sessions exist, creates and enqueues the next batch
5. **Complete**: When all sessions are processed or no more space, marks as completed

### 3. **Self-Chaining Logic**
```apex
// Check if we should continue
Integer remainingCount = countUnscheduledSessions();
if (remainingCount > 0) {
    // More sessions to schedule, self-queue for next batch
    selfQueueNextBatch();
} else {
    // All sessions scheduled, mark as completed
    updateAsyncSessionStatus(asyncSessionId, 'Completed', 
        'Successfully scheduled all sessions in batches.');
}
```

## Constructor Options

### Default Constructor
```apex
// Processes 10 sessions per batch
SchedulingAgentQueueable queueable = new SchedulingAgentQueueable(
    asyncSessionId, userMessage, sessionId
);
```

### Custom Batch Size Constructor
```apex
// Processes 5 sessions per batch
SchedulingAgentQueueable queueable = new SchedulingAgentQueueable(
    asyncSessionId, userMessage, sessionId, 5
);
```

## State Management

The class maintains minimal state across batch executions:

- **`batchSize`**: Number of sessions to process per batch
- **`totalProcessed`**: Total number of sessions processed so far

## Agent Response Format

The agent is expected to return responses in this format:

```json
{
  "proposedSchedule": [
    {
      "sessionName": "Session Name",
      "speakers": ["Speaker 1", "Speaker 2"],
      "location": "Room Name",
      "startTime": "2025-08-15T09:00:00Z",
      "endTime": "2025-08-15T09:45:00Z",
      "format": "Session Format",
      "focus": "Session Focus",
      "sessionAbstract": "Session description"
    }
  ],
  "noMoreSpace": false,
  "message": "Additional scheduling information",
  "sessionId": "conversation-session-id"
}
```

### Key Fields:
- **`proposedSchedule`**: Array of session slots to be created
- **`noMoreSpace`**: Boolean indicating if no more space is available
- **`message`**: Additional information from the agent
- **`sessionId`**: Conversation session ID for maintaining context across batches (required on first response)

### Session ID Handling:
- **First Request**: No session ID is sent to the agent
- **First Response**: Agent should return a `sessionId` for conversation continuity
- **Subsequent Requests**: The captured session ID is sent to maintain conversation context
- **Benefits**: Allows the agent to remember previous scheduling decisions and maintain consistency

## Error Handling

- **Batch Failures**: If a batch fails to process, the async session is marked as failed
- **Self-Queue Failures**: If self-queuing fails, the session is marked as failed
- **Agent Failures**: If the AI agent fails, the session is marked as failed with detailed error information
- **No More Space**: If the agent indicates no more space, the process completes successfully

## Usage Example

```apex
// Start the self-chaining scheduling process
Async_Agent_Session__c asyncSession = new Async_Agent_Session__c(
    Agent_API_Name__c = 'Scheduling_Agent_1',
    User_Message__c = 'Please schedule all unscheduled sessions for the conference',
    Status__c = 'Pending',
    Started_At__c = System.now()
);

insert asyncSession;

// Enqueue the self-chaining queueable
SchedulingAgentQueueable executor = new SchedulingAgentQueueable(
    asyncSession.Id, 
    'Please schedule all unscheduled sessions for the conference',
    null,
    10  // Process 10 sessions per batch
);

System.enqueueJob(executor);
```

## Benefits

### 1. **Simplicity**
- Cleaner, more focused code
- Agent handles complex session logic
- Queueable focuses on coordination and self-chaining

### 2. **Scalability**
- Can handle conferences with hundreds of sessions
- Automatically scales processing based on available resources
- No manual intervention required for large scheduling tasks

### 3. **Reliability**
- Self-healing through automatic retry mechanism
- Progress tracking prevents duplicate processing
- Graceful error handling and recovery

### 4. **Flexibility**
- Agent can make intelligent decisions about which sessions to schedule
- Agent can indicate when no more space is available
- Easy to modify agent behavior without changing queueable logic

## Limitations and Considerations

### 1. **Queueable Limits**
- Maximum of 5 chained queueable jobs
- Total execution time across all chained jobs cannot exceed 24 hours
- Memory and CPU limits apply to each individual execution

### 2. **Agent Dependency**
- Relies on the AI agent for session decisions
- Agent must properly format responses
- Agent must accurately indicate when no more space is available

### 3. **State Persistence**
- Minimal state is maintained in memory during execution
- If a queueable job fails, minimal state may be lost
- Progress tracking is based on actual database state

## Future Enhancements

### 1. **Enhanced Agent Communication**
- Add more structured communication protocols
- Implement agent response validation
- Add agent performance metrics

### 2. **Advanced Progress Tracking**
- Store progress in custom objects for better recovery
- Implement checkpointing for very long-running processes
- Add resume capability for interrupted scheduling jobs

### 3. **Monitoring and Alerting**
- Add real-time progress monitoring
- Implement alerts for failed batches
- Add performance metrics and analytics

## Testing

Use the provided test script `scripts/apex/test-self-chaining-queueable.apex` to verify the functionality:

```bash
# Execute the test script
sf apex run -f scripts/apex/test-self-chaining-queueable.apex
```

## Conclusion

The refactored `SchedulingAgentQueueable` class provides a clean, simple solution for coordinating with AI agents to schedule conference sessions. Its simplified self-chaining architecture ensures that all sessions are processed automatically while maintaining efficient resource usage and providing clear progress tracking. The separation of concerns between the queueable (coordination) and the agent (session decisions) makes the system more maintainable and flexible. 