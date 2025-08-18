# Scheduling Agent Async Implementation

## Overview

This document describes the new asynchronous implementation for the scheduling agent that addresses response truncation issues by utilizing increased heap and CPU limits through Salesforce queueable jobs.

## Problem Statement

The previous async implementation still used the same `GenerateAiAgentResponse.generateResponse` method, which had the same heap and CPU limits as synchronous operations. This resulted in responses being truncated when generating large schedules.

## Solution

### New Architecture

1. **SchedulingAgentQueueable**: A dedicated queueable class that runs in a separate transaction with increased resource limits
2. **Direct Async Session Management**: Bypasses the generic AsyncAgentController for scheduling-specific operations
3. **Enhanced Chunking**: Implements response chunking at the queueable level for very large responses
4. **Improved LWC Polling**: Better status monitoring and progress tracking

### Key Benefits

- **Increased Heap Limit**: Queueable jobs have higher heap limits (12MB vs 6MB in synchronous contexts)
- **Increased CPU Limit**: Queueable jobs have higher CPU time limits (60 seconds vs 10 seconds)
- **Better Error Handling**: Specific error messages for resource limit issues
- **Improved User Experience**: Real-time status updates and progress tracking

## Implementation Details

### 1. SchedulingAgentQueueable Class

```apex
public class SchedulingAgentQueueable implements Queueable, Database.AllowsCallouts {
    // Runs in separate transaction with increased limits
    // Handles large responses with automatic chunking
    // Provides detailed logging for debugging
}
```

**Features:**
- Automatic response chunking for responses > 100KB
- Detailed resource usage logging
- Comprehensive error handling
- Status updates throughout processing

### 2. Enhanced ScheduleAgentController

The `invokeSchedulingAgentAsync` method now:
- Creates async session records directly
- Enqueues the dedicated SchedulingAgentQueueable
- Returns enhanced status information
- Includes queueable type for debugging

### 3. Improved LWC Implementation

**Enhanced Polling:**
- 3-second polling interval for better performance
- Status-based progress updates
- Automatic interval cleanup
- Better error handling and user feedback

**Progress Tracking:**
- Real-time status updates
- Visual progress indicators
- Status-specific user messages
- Automatic cleanup on completion/failure

## Usage

### Frontend (LWC)

```javascript
// Initiate async scheduling
buildProposedScheduleAsync() {
    // This now uses the new queueable implementation
    invokeSchedulingAgentAsync({ userMessage: 'Generate schedule...' })
        .then(response => {
            // Handle initiation response
            this.handleAsyncAgentInitiation(response);
        });
}

// Monitor progress
startAsyncSessionMonitoring() {
    // Enhanced polling with better status handling
    this.pollAsyncSessionStatus();
    this.simulateAsyncProgress();
}
```

### Backend (Apex)

```apex
// The new implementation automatically handles:
// 1. Creating async session records
// 2. Enqueueing the queueable job
// 3. Processing with increased limits
// 4. Response chunking if needed
// 5. Status updates throughout the process

Map<String, Object> result = ScheduleAgentController.invokeSchedulingAgentAsync(userMessage);
```

## Testing

### Test Script

Use the provided test script to verify the implementation:

```apex
// Run in Developer Console or via SFDX
@isTest
// See: scripts/apex/test-scheduling-queueable.apex
```

### Monitoring

Monitor async sessions in the `Async_Agent_Session__c` object:
- Status updates: Pending → Processing → Completed/Failed
- Processing time tracking
- Error message details
- Response length information

## Configuration

### Queueable Limits

- **Heap**: 12MB (vs 6MB in synchronous)
- **CPU Time**: 60 seconds (vs 10 seconds in synchronous)
- **DML Rows**: 10,000 (vs 150 in synchronous)
- **SOQL Queries**: 100 (vs 20 in synchronous)

### Polling Configuration

- **Polling Interval**: 3 seconds (configurable)
- **Progress Update**: 2 seconds (configurable)
- **Timeout**: 5 minutes (configurable)

## Troubleshooting

### Common Issues

1. **Queueable Job Not Starting**
   - Check debug logs for enqueueing errors
   - Verify Async_Agent_Session__c record creation
   - Check governor limits

2. **"Uncommitted Work" Callout Errors**
   - **FIXED**: The queueable no longer performs DML operations before making callouts
   - Status updates now happen after callout completion
   - Check debug logs for detailed execution flow

3. **Response Still Truncated**
   - Verify the queueable is running (check debug logs)
   - Check if chunking is working properly
   - Monitor heap usage in debug logs

4. **Polling Not Working**
   - Check for JavaScript errors in browser console
   - Verify interval cleanup methods
   - Check network requests to Apex methods

### Recent Fixes

**Issue**: "A callout was unsuccessful because of pending uncommitted work related to a process, flow, or Apex operation"

**Root Cause**: The queueable was updating the session status to "Processing" before making the callout, which caused DML operations to occur before the callout.

**Solution**: 
1. Removed DML operations before callout in the queueable
2. Status is now set to "Processing" in ScheduleAgentController after enqueueing
3. Added extensive debug logging to track execution flow

**Files Modified**:
- `SchedulingAgentQueueable.cls` - Removed DML before callout
- `ScheduleAgentController.cls` - Status update moved to after enqueueing
- Enhanced debug logging throughout the execution flow

### Debug Information

The implementation provides extensive debug logging:
- Resource usage throughout processing
- Response length tracking
- Chunking operations
- Error details and stack traces

## Migration Notes

### From Previous Implementation

1. **No Breaking Changes**: The LWC interface remains the same
2. **Enhanced Status Updates**: Better progress tracking and user feedback
3. **Improved Error Handling**: More specific error messages
4. **Automatic Cleanup**: Better resource management

### Backward Compatibility

- Existing async sessions continue to work
- Synchronous mode unchanged
- All existing methods preserved

## Future Enhancements

1. **Batch Processing**: For very large schedules
2. **Retry Logic**: Automatic retry on failures
3. **Priority Queuing**: Different priority levels for different request types
4. **Webhook Notifications**: Real-time completion notifications
5. **Response Caching**: Cache completed schedules for reuse

## Support

For issues or questions:
1. Check debug logs for detailed error information
2. Verify Async_Agent_Session__c record status
3. Monitor resource usage in queueable execution
4. Review LWC console logs for frontend issues 