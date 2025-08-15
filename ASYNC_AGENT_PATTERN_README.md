# Asynchronous AI Agent Pattern for Conference Scheduler

This document describes the asynchronous pattern implemented for AI agent operations in the Conference Scheduler application. This pattern allows for long-running AI agent operations without blocking the user interface.

## Overview

The asynchronous pattern consists of several components that work together to provide a non-blocking experience for users when generating conference schedules:

1. **Async_Agent_Session__c Object** - Tracks the state of async agent operations
2. **AsyncAgentExecutor** - Queueable class that executes AI agents in the background
3. **AsyncAgentController** - Manages async agent operations and provides status updates
4. **Updated ScheduleAgentController** - Integrates async operations with existing scheduling logic
5. **Enhanced Frontend** - Provides progress tracking and status updates

## Architecture

### 1. Data Model

The `Async_Agent_Session__c` custom object tracks:
- **Status**: Pending, Processing, Completed, Failed, Cancelled
- **Agent Details**: API name, user message, session ID
- **Timing**: Start time, completion time, processing duration
- **Results**: Agent response or error messages

### 2. Backend Components

#### AsyncAgentExecutor (Queueable)
- Implements `Queueable` and `Database.AllowsCallouts` interfaces
- Executes AI agents in the background using the existing `GenerateAiAgentResponse` class
- Updates session status throughout the process
- Handles errors gracefully and updates the session record

#### AsyncAgentController
- **initiateAsyncAgentSession()**: Creates async session and enqueues execution
- **getAsyncAgentSessionStatus()**: Retrieves current status and results
- **cancelAsyncAgentSession()**: Cancels ongoing operations
- **waitForAsyncAgentSession()**: Waits for completion with timeout
- **getUserAsyncSessions()**: Lists user's async sessions

#### ScheduleAgentController Updates
- **invokeSchedulingAgentAsync()**: Initiates async scheduling operations
- **getAsyncSchedulingAgentStatus()**: Gets status of async scheduling sessions
- **waitForAsyncSchedulingAgent()**: Waits for async scheduling completion

### 3. Frontend Enhancements

The Lightning Web Component (`conferenceScheduler`) now supports:
- **Async Mode Selection**: Users can choose between synchronous and asynchronous processing
- **Progress Tracking**: Real-time progress bar and status updates
- **Session Monitoring**: Automatic polling for status changes
- **Cancellation**: Ability to cancel ongoing async operations
- **Seamless Integration**: Same result handling for both sync and async modes

## Usage Patterns

### 1. Initiating Async Operations

```javascript
// User selects async mode
this.selectedOption = 'new-async';

// Frontend calls async method
buildProposedScheduleAsync() {
    invokeSchedulingAgentAsync({ userMessage: userMessage })
        .then(response => {
            this.handleAsyncAgentInitiation(response);
        });
}
```

### 2. Monitoring Progress

```javascript
// Start monitoring the async session
startAsyncSessionMonitoring() {
    this.pollAsyncSessionStatus();
    this.simulateAsyncProgress();
}

// Poll for status updates every 2 seconds
pollAsyncSessionStatus() {
    const pollInterval = setInterval(() => {
        getAsyncSchedulingAgentStatus({ asyncSessionId: this.asyncSessionId })
            .then(statusResponse => {
                if (statusResponse.status === 'Completed') {
                    this.handleAsyncAgentCompletion(statusResponse);
                }
            });
    }, 2000);
}
```

### 3. Handling Completion

```javascript
handleAsyncAgentCompletion(statusResponse) {
    // Parse the completed agent response
    if (statusResponse.parsedSchedule) {
        this.handleAgentResponse({
            success: true,
            agentResponse: statusResponse.agentResponse,
            message: 'Schedule generated successfully (async)'
        });
    }
}
```

## Benefits

### 1. **Non-blocking User Experience**
- Users can continue using the application while AI agents process
- No timeout issues for long-running operations
- Better user engagement and productivity

### 2. **Scalability**
- Multiple async operations can run simultaneously
- Queueable jobs handle system load gracefully
- Better resource utilization

### 3. **Reliability**
- Failed operations are tracked and can be retried
- Progress monitoring provides transparency
- Error handling is more robust

### 4. **Flexibility**
- Users can choose between sync and async modes
- Operations can be cancelled if needed
- Status updates provide real-time feedback

## Configuration

### Timeout Settings
- **Default Timeout**: 5 minutes (300 seconds)
- **Configurable**: Can be adjusted per operation
- **Graceful Handling**: Timeout events are handled gracefully

### Polling Intervals
- **Status Polling**: Every 2 seconds
- **Progress Updates**: Every 1 second
- **Configurable**: Intervals can be adjusted based on requirements

## Error Handling

### 1. **Agent Failures**
- Errors are captured and stored in the session record
- Frontend displays appropriate error messages
- Users can retry or switch to synchronous mode

### 2. **System Failures**
- Queueable job failures are handled gracefully
- Session status is updated to reflect failures
- Debug information is logged for troubleshooting

### 3. **Timeout Handling**
- Long-running operations can timeout gracefully
- Users are notified of timeout events
- Partial results can be retrieved if available

## Monitoring and Debugging

### 1. **Debug Logs**
- Comprehensive logging throughout the async process
- Status updates and timing information
- Error details and stack traces

### 2. **Session Records**
- Complete audit trail of async operations
- Processing times and status changes
- Error messages and responses

### 3. **Frontend Console**
- Real-time status updates in browser console
- Progress tracking and completion events
- Error handling and user feedback

## Best Practices

### 1. **User Experience**
- Always provide clear feedback about operation status
- Use progress indicators for long-running operations
- Allow users to cancel operations when appropriate

### 2. **Error Handling**
- Capture and log all errors for debugging
- Provide meaningful error messages to users
- Implement retry mechanisms where appropriate

### 3. **Performance**
- Use appropriate polling intervals to balance responsiveness and system load
- Implement timeouts to prevent indefinite waiting
- Clean up resources when operations complete or fail

### 4. **Monitoring**
- Track processing times to identify performance issues
- Monitor failure rates and error patterns
- Implement alerting for critical failures

## Future Enhancements

### 1. **Real-time Updates**
- Implement Platform Events for real-time status updates
- Use Streaming API for live progress monitoring
- Reduce polling overhead

### 2. **Advanced Queuing**
- Implement priority queuing for different operation types
- Add retry mechanisms with exponential backoff
- Support for batch operations

### 3. **Enhanced Monitoring**
- Dashboard for monitoring async operations
- Performance metrics and analytics
- Automated alerting and notifications

### 4. **Integration**
- Support for multiple AI agent types
- Integration with external scheduling systems
- Webhook support for external notifications

## Conclusion

The asynchronous AI agent pattern provides a robust, scalable solution for handling long-running AI operations in the Conference Scheduler. By separating the execution from the user interface, it enables better user experience, improved system reliability, and enhanced scalability.

The pattern is designed to be extensible and can be easily adapted for other AI agent operations beyond conference scheduling. The modular architecture allows for easy maintenance and enhancement of individual components. 