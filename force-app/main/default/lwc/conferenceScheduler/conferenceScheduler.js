import { LightningElement, api, track } from 'lwc';
import getEvents from '@salesforce/apex/ScheduleAgentController.getEvents';
import invokeSchedulingAgentAsync from '@salesforce/apex/ScheduleAgentController.invokeSchedulingAgentAsync';
import getAsyncSchedulingAgentStatus from '@salesforce/apex/ScheduleAgentController.getAsyncSchedulingAgentStatus';
import getScheduledSessions from '@salesforce/apex/ScheduleAgentController.getScheduledSessions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ConferenceScheduler extends LightningElement {
    @api eventId;
    @track isLoading = false;
    @track errorMessage = '';
    @track selectedOption = '';
    @track selectedEventId = '';
    @track isLoadingEvents = false;
    @track events = [];
    @track proposedSchedule = null;
    @track showResults = false;
    @track scheduleOptions = [
        { label: 'Create New Conference Schedule (Async)', value: 'new-async' },
        { label: 'Modify Existing Conference Schedule', value: 'modify' }
    ];
    
    // Async operation properties
    @track isAsyncMode = false;
    @track asyncSessionId = null;
    @track asyncStatus = null;
    @track asyncProgress = 0;
    @track asyncTimeout = 300; // 5 minutes default timeout
    @track showAsyncProgress = false;
    @track isWaitingForParts = false;
    @track partialResponses = null;

    // Table configuration
    scheduleTableColumns = [
        {
            label: 'Session Name',
            fieldName: 'sessionName',
            type: 'text',
            sortable: true,
            wrapText: true,
            initialWidth: 250,
            cellAttributes: {
                class: 'slds-cell-buffer'
            }
        },
        {
            label: 'Speakers',
            fieldName: 'displaySpeakers',
            type: 'text',
            sortable: false,
            wrapText: true,
            initialWidth: 200,
            cellAttributes: {
                class: 'slds-cell-buffer'
            }
        },
        {
            label: 'Location',
            fieldName: 'location',
            type: 'text',
            sortable: true,
            initialWidth: 150,
            cellAttributes: {
                class: 'slds-cell-buffer'
            }
        },
        {
            label: 'Date',
            fieldName: 'displayDate',
            type: 'text',
            sortable: true,
            initialWidth: 100,
            cellAttributes: {
                class: 'slds-cell-buffer'
            }
        },
        {
            label: 'Time',
            fieldName: 'displayTime',
            type: 'text',
            sortable: true,
            initialWidth: 150,
            cellAttributes: {
                class: 'slds-cell-buffer'
            }
        },
        {
            label: 'Duration',
            fieldName: 'displayDuration',
            type: 'text',
            sortable: true,
            initialWidth: 100,
            cellAttributes: {
                class: 'slds-cell-buffer'
            }
        }
    ];

    // Sorting state
    sortBy = 'displayDate';
    sortDirection = 'asc';
    
    get showEventSelection() {
        return this.selectedOption === 'new' || this.selectedOption === 'new-async';
    }

    get hasEvents() {
        return this.events && this.events.length > 0;
    }

    get eventOptions() {
        return this.events.map(event => ({
            label: `${event.Name} (${this.formatDate(event.Event_Start_Date__c)} - ${this.formatDate(event.Event_End_Date__c)})${event.Event_Timezone__c ? ` - ${event.Event_Timezone__c}` : ''}`,
            value: event.Id
        }));
    }

    get isContinueDisabled() {
        if (this.selectedOption === 'new') {
            return !this.selectedEventId;
        }
        return !this.selectedOption;
    }

    handleOptionChange(event) {
        this.selectedOption = event.detail.value;
        this.selectedEventId = this.selectedOption.Id;
        if (this.selectedOption === 'new-async') {
            this.loadEvents();
        } else {
            this.selectedEventId = '';
        }
    }

    handleEventChange(event) {
        this.selectedEventId = event.detail.value;
    }

    async loadEvents() {
        this.isLoadingEvents = true;
        try {
            this.events = await getEvents();
        } catch (error) {
            console.error('Error loading events:', error);
            this.errorMessage = 'Failed to load events. Please try again.';
        } finally {
            this.isLoadingEvents = false;
        }
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString();
    }
    


    handleContinue() {
        if (this.selectedOption === 'new-async') {
            this.buildProposedScheduleAsync();
        } else if (this.selectedOption === 'modify') {
            this.handleModifySchedule();
        }
    }

    handleCancel() {
        this.resetForm();
    }

    buildProposedScheduleAsync() {
        this.isLoading = true;
        this.errorMessage = '';
        this.isAsyncMode = true;
        this.showAsyncProgress = true;
        this.asyncProgress = 0;
        
        try {
            // Enhanced message for the agent with specific JSON structure
            const userMessage = 'Generate a proposed schedule for '+this.selectedEventId+' based on available rooms and time slots. Save the proposed schedule as Session Slots marked draft. Before selecting times and locations, check the availability of the rooms and time slots. Never schedule a session in a room with a time that overlaps with another session.';
            
            console.log('Calling async schedule agent with message:', userMessage);
            
            // Call the Apex method to initiate the async scheduling agent
            invokeSchedulingAgentAsync({ userMessage: userMessage })
                .then(response => {
                    console.log('Async agent initiation response:', response);
                    this.handleAsyncAgentInitiation(response);
                })
                .catch(error => {
                    console.error('Error calling async schedule agent:', error);
                    this.isLoading = false;
                    this.isAsyncMode = false;
                    this.showAsyncProgress = false;
                    this.errorMessage = error.body?.message || error.message || 'Failed to call async schedule agent';
                });
            
        } catch (error) {
            console.error('Error in buildProposedScheduleAsync:', error);
            this.errorMessage = 'Failed to build proposed schedule asynchronously. Please try again.';
            this.isLoading = false;
            this.isAsyncMode = false;
            this.showAsyncProgress = false;
        }
    }

    handleAsyncAgentInitiation(response) {
        if (response.success && response.isAsync) {
            this.asyncSessionId = response.asyncSessionId;
            this.asyncStatus = 'Processing'; // Set to Processing immediately since the job is queued
            this.isLoading = false;
            
            console.log('Async agent session initiated successfully:', response.asyncSessionId);
            
            // Start monitoring the async session
            this.startAsyncSessionMonitoring();
            
            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Async Session Started',
                    message: 'Your schedule request has been submitted and is being processed asynchronously. You can monitor progress below.',
                    variant: 'success'
                })
            );
        } else {
            // Handle failure
            this.isLoading = false;
            this.isAsyncMode = false;
            this.showAsyncProgress = false;
            this.errorMessage = response.message || 'Failed to initiate async session';
            
            console.error('Failed to initiate async session:', response);
        }
    }
    
    startAsyncSessionMonitoring() {
        if (!this.asyncSessionId) return;
        
        // Start polling for status updates
        this.pollAsyncSessionStatus();
        
        // Also set up a progress bar simulation
        this.simulateAsyncProgress();
    }
    
    pollAsyncSessionStatus() {
        if (!this.asyncSessionId) return;
        
        console.log('Starting async session polling for session:', this.asyncSessionId);
        
        const pollInterval = setInterval(() => {
            if (!this.asyncSessionId) {
                clearInterval(pollInterval);
                return;
            }
            
            // Check the status of the async session
            getAsyncSchedulingAgentStatus({ asyncSessionId: this.asyncSessionId })
                .then(statusResponse => {
                    console.log('Async session status update:', statusResponse);
                    this.asyncStatus = statusResponse.status;
                    
                    // Update progress based on status
                    if (statusResponse.status === 'Pending') {
                        this.asyncProgress = 10;
                    } else if (statusResponse.status === 'Processing') {
                        this.asyncProgress = Math.min(this.asyncProgress + 15, 85);
                    } else if (statusResponse.status === 'Completed') {
                        this.asyncProgress = 100;
                        clearInterval(pollInterval);
                        this.handleAsyncAgentCompletion(statusResponse);
                    } else if (statusResponse.status === 'Failed') {
                        this.asyncProgress = 100;
                        clearInterval(pollInterval);
                        this.handleAsyncAgentFailure(statusResponse);
                    }
                    
                    // Show status-specific messages
                    this.updateAsyncStatusMessage(statusResponse.status);
                    
                })
                .catch(error => {
                    console.error('Error polling async session status:', error);
                    // Continue polling on error, but show error in UI
                    this.errorMessage = 'Error checking status: ' + (error.body?.message || error.message || 'Unknown error');
                    // Continue polling on error
                });
        }, 15000); // Poll every 15 seconds for better performance
        
        // Store the interval ID so we can clear it if needed
        this.pollIntervalId = pollInterval;
    }
    
    updateAsyncStatusMessage(status) {
        let message = '';
        switch (status) {
            case 'Pending':
                message = 'Your request is queued and waiting to be processed...';
                break;
            case 'Processing':
                message = 'The scheduling agent is actively working on your request. This may take several minutes for complex schedules.';
                break;
            case 'Completed':
                message = 'Schedule generation completed successfully!';
                break;
            case 'Failed':
                message = 'Schedule generation failed. Please check the error details below.';
                break;
            default:
                message = 'Processing your schedule request...';
        }
        
        // Update the status message in the UI
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Status Update',
                message: message,
                variant: status === 'Failed' ? 'error' : 'info',
                duration: status === 'Completed' || status === 'Failed' ? 5000 : 3000
            })
        );
    }
    
    simulateAsyncProgress() {
        if (!this.asyncSessionId) return;
        
        const progressInterval = setInterval(() => {
            if (!this.asyncSessionId || this.asyncStatus === 'Completed' || this.asyncStatus === 'Failed') {
                clearInterval(progressInterval);
                return;
            }
            
            // Only simulate progress when status is Processing and we're not near completion
            if (this.asyncStatus === 'Processing' && this.asyncProgress < 85) {
                // Gradual progress increase to show activity
                this.asyncProgress += Math.random() * 5;
            }
        }, 2000); // Update progress every 2 seconds to avoid too frequent updates
        
        // Store the interval ID so we can clear it if needed
        this.progressIntervalId = progressInterval;
    }
    
    handleAsyncAgentCompletion(statusResponse) {
        this.isLoading = false;
        this.isAsyncMode = false;
        this.showAsyncProgress = false;
        this.asyncProgress = 100;
        
        console.log('Async agent session completed successfully');
        console.log('=== handleAsyncAgentCompletion debugging ===');
        console.log('statusResponse keys:', Object.keys(statusResponse));
        console.log('statusResponse.parsedSchedule:', statusResponse.parsedSchedule);
        console.log('statusResponse.agentResponse:', statusResponse.agentResponse);
        
        // Check if we have a direct agent response (e.g., completion message from queueable)
        if (statusResponse.agentResponse && !statusResponse.agentResponse.startsWith('{')) {
            console.log('Found direct agent response (likely completion message)');
            
            // This is a plain text completion message, use it directly
            const completionMessage = statusResponse.agentResponse;
            
            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Schedule Processing Completed',
                    message: completionMessage,
                    variant: 'success'
                })
            );
            
            // Update the proposedSchedule to indicate success
            this.proposedSchedule = {
                success: true,
                schedule: [], // We'll query the database for actual slots
                totalSessions: 0, // Will be determined by database query
                locations: [],
                timeRange: { start: null, end: null },
                message: completionMessage,
                error: null,
                note: 'Schedule processing completed. Querying database for scheduled sessions...'
            };
            
            this.showResults = true;
            
            // Query the database for the actual scheduled sessions
            this.queryScheduledSessions();
            return;
        }
        
        // Check if the backend successfully parsed the agent response
        if (statusResponse.parsedSchedule && statusResponse.parsedSchedule.success) {
            console.log('Backend successfully parsed agent response');
            
            const parsedSchedule = statusResponse.parsedSchedule;
            const slotsUpserted = parsedSchedule.slotsUpserted || 0;
            const message = parsedSchedule.message || 'Schedule generated successfully';
            
            if (parsedSchedule.scheduleGenerated) {
                // Agent successfully created draft slots
                console.log('Agent successfully created draft slots:', slotsUpserted);
                
                // Show success message
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Schedule Generated Successfully',
                        message: `Successfully created ${slotsUpserted} draft session slots. The schedule is now available in the database.`,
                        variant: 'success'
                    })
                );
                
                // Update the proposedSchedule to indicate success
                this.proposedSchedule = {
                    success: true,
                    schedule: [], // We'll query the database for actual slots
                    totalSessions: slotsUpserted,
                    locations: [],
                    timeRange: { start: null, end: null },
                    message: message,
                    error: null,
                    note: `Agent created ${slotsUpserted} draft session slots. Query the database to see the actual schedule.`
                };
                
                this.showResults = true;
                
                // Query the database for the actual scheduled sessions
                this.queryScheduledSessions();
                
            } else {
                // Agent failed to create slots
                console.error('Agent failed to create draft slots');
                
                this.errorMessage = message || 'Agent failed to create draft slots';
                
                // Show error message
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Schedule Generation Failed',
                        message: message || 'Failed to generate schedule. Please check the error details.',
                        variant: 'error'
                    })
                );
            }
            
        } else if (statusResponse.parsedSchedule && !statusResponse.parsedSchedule.success) {
            // Backend parsing succeeded but agent reported failure
            console.error('Agent reported failure:', statusResponse.parsedSchedule.error);
            
            // Check if we have a more informative message in the raw response
            let errorMessage = statusResponse.parsedSchedule.error || 'Agent reported failure';
            if (statusResponse.parsedSchedule.rawResponse && 
                !statusResponse.parsedSchedule.rawResponse.startsWith('{')) {
                // Use the raw response if it's more informative
                errorMessage = statusResponse.parsedSchedule.rawResponse;
            }
            
            this.errorMessage = errorMessage;
            
            // Show error message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Schedule Generation Failed',
                    message: errorMessage,
                    variant: 'error'
                })
            );
            
        } else {
            // Backend parsing failed or no parsedSchedule available
            console.error('Backend parsing failed or no parsedSchedule available');
            
            // Check if we have a direct agent response we can use
            if (statusResponse.agentResponse) {
                this.errorMessage = statusResponse.agentResponse;
            } else {
                this.errorMessage = 'Failed to parse agent response';
            }
            
            // Show error message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Schedule Generation Failed',
                    message: this.errorMessage,
                    variant: 'error'
                })
            );
        }
        
        // Clean up intervals
        this.cleanupAsyncIntervals();
    }
    
    handleAsyncAgentFailure(statusResponse) {
        this.isLoading = false;
        this.isAsyncMode = false;
        this.showAsyncProgress = false;
        
        console.error('Async agent session failed:', statusResponse);
        
        // Extract error information
        let errorMessage = 'Async agent session failed';
        let detailedError = '';
        
        if (statusResponse.errorMessage) {
            errorMessage = statusResponse.errorMessage;
            detailedError = statusResponse.errorMessage;
        } else if (statusResponse.error) {
            errorMessage = statusResponse.error;
            detailedError = statusResponse.error;
        }
        
        // Check if this is a resource limit error
        if (detailedError.toLowerCase().includes('heap') || detailedError.toLowerCase().includes('cpu')) {
            errorMessage = 'Schedule generation failed due to resource limits. The response may be too large for processing.';
            detailedError += ' Consider requesting a smaller schedule or breaking it into multiple requests.';
        } else if (detailedError.toLowerCase().includes('callout')) {
            errorMessage = 'Schedule generation failed due to external service issues. Please try again later.';
        }
        
        this.errorMessage = detailedError || errorMessage;
        
        // Show error message
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Async Session Failed',
                message: errorMessage,
                variant: 'error'
            })
        );
        
        // Clean up intervals
        this.cleanupAsyncIntervals();
    }
    
    handleAgentResponse(response) {
        this.isLoading = false;
        
        // Initialize a default structure for proposedSchedule
        this.proposedSchedule = {
            success: false,
            schedule: [],
            totalSessions: 0,
            locations: [],
            timeRange: { start: null, end: null },
            message: 'No schedule data available',
            error: null
        };
        
        if (response.success) {
            // Check if the response was chunked due to size
            if (response.isChunked && response.chunks) {
                // Reconstruct the full response from chunks
                const fullResponse = this.reconstructChunkedResponse(response.chunks);
                response.agentResponse = fullResponse;
                response.isChunked = false;
                
                console.log('Reconstructed full response from', response.totalChunks, 'chunks');
                console.log('Full response length:', fullResponse.length);
            }
            
            // Check if the response contains multiple parts that need to be combined
            const combinedResponse = this.combineMultipleResponses(response.agentResponse);
            if (combinedResponse !== response.agentResponse) {
                console.log('Response was combined from multiple parts');
                response.agentResponse = combinedResponse;
            }
            
            console.log('Agent response:', response.agentResponse);
            
            // Parse the agent response to extract the schedule
            const parsedSchedule = this.parseAgentResponse(response.agentResponse);
            console.log('Parsed schedule:', parsedSchedule);
            
            if (parsedSchedule.success) {
                // Update the proposedSchedule with successful parsing results
                this.proposedSchedule = {
                    success: true,
                    schedule: parsedSchedule.schedule || [],
                    totalSessions: parsedSchedule.totalSessions || 0,
                    locations: parsedSchedule.locations || [],
                    timeRange: parsedSchedule.timeRange || { start: null, end: null },
                    message: response.message || 'Schedule generated successfully',
                    error: null,
                    note: parsedSchedule.note || '' // Add the note from parsedSchedule
                };
                
                this.showResults = true;
                this.logScheduleDebugInfo();
            } else {
                // Parsing failed, update with error information
                this.proposedSchedule = {
                    success: false,
                    schedule: [],
                    totalSessions: 0,
                    locations: [],
                    timeRange: { start: null, end: null },
                    message: 'Failed to parse schedule data',
                    error: parsedSchedule.error || 'Unknown parsing error',
                    rawResponse: parsedSchedule.rawResponse || response.agentResponse,
                    note: parsedSchedule.note || '' // Add the note from parsedSchedule
                };
                
                this.errorMessage = parsedSchedule.error || 'Failed to parse schedule data';
                console.error('Failed to parse schedule:', parsedSchedule.error);
            }
        } else {
            // Agent invocation failed
            this.proposedSchedule = {
                success: false,
                schedule: [],
                totalSessions: 0,
                locations: [],
                timeRange: { start: null, end: null },
                message: response.message || 'Agent invocation failed',
                error: response.error || 'Unknown error',
                rawResponse: response.rawResponse || null,
                note: '' // No note for failed agent invocation
            };
            
            this.errorMessage = response.message || 'Failed to generate schedule';
            console.error('Agent invocation failed:', response);
        }
    }
    
    /**
     * Reconstructs a full response from chunked data
     * @param {Array} chunks - Array of response chunks
     * @returns {string} - The reconstructed full response
     */
    reconstructChunkedResponse(chunks) {
        if (!chunks || !Array.isArray(chunks)) {
            return '';
        }
        
        // Sort chunks if they have order information, otherwise concatenate in order
        return chunks.join('');
    }
    
    /**
     * Combines multiple sequential responses from the AI agent
     * @param {string} agentResponse - The raw response from the agent
     * @returns {string} - The combined response
     */
    combineMultipleResponses(agentResponse) {
        if (!agentResponse) {
            return '';
        }
        
        console.log('=== combineMultipleResponses called ===');
        console.log('Original response length:', agentResponse.length);
        console.log('Original response preview:', agentResponse.substring(0, 500));
        
        // Clean the response first - remove leading/trailing invalid characters
        let cleanedResponse = agentResponse.trim();
        
        // Remove leading characters that aren't valid JSON starters
        while (cleanedResponse.length > 0 && 
               !cleanedResponse.startsWith('{') && 
               !cleanedResponse.startsWith('[') && 
               !cleanedResponse.startsWith('"')) {
            cleanedResponse = cleanedResponse.substring(1);
        }
        
        // Remove trailing characters that aren't valid JSON enders
        while (cleanedResponse.length > 0 && 
               !cleanedResponse.endsWith('}') && 
               !cleanedResponse.endsWith(']') && 
               !cleanedResponse.endsWith('"')) {
            cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length - 1);
        }
        
        if (cleanedResponse !== agentResponse) {
            console.log('Cleaned response from', agentResponse.length, 'to', cleanedResponse.length, 'characters');
            console.log('Cleaned response preview:', cleanedResponse.substring(0, 200));
        }
        
        // Check if the response contains multiple JSON objects or arrays
        // Look for patterns that indicate multiple responses
        
        // Pattern 1: Multiple complete JSON objects separated by whitespace/newlines
        const jsonObjects = this.extractMultipleJsonObjects(cleanedResponse);
        if (jsonObjects.length > 1) {
            console.log('Found multiple JSON objects:', jsonObjects.length);
            return this.combineJsonObjects(jsonObjects);
        }
        
        // Pattern 2: Multiple JSON arrays that need to be merged
        const jsonArrays = this.extractMultipleJsonArrays(cleanedResponse);
        if (jsonArrays.length > 1) {
            console.log('Found multiple JSON arrays:', jsonArrays.length);
            return this.combineJsonArrays(jsonArrays);
        }
        
        // Pattern 3: Check for explicit part indicators in the response
        if (cleanedResponse.includes('Part 1') || cleanedResponse.includes('Part 2') || 
            cleanedResponse.includes('Response 1') || cleanedResponse.includes('Response 2')) {
            console.log('Found explicit part indicators in response');
            return this.combinePartedResponses(cleanedResponse);
        }
        
        // Pattern 4: Check if this is a Salesforce AI agent response wrapper
        if (cleanedResponse.includes('"type":"Text"') && cleanedResponse.includes('"value":')) {
            console.log('Found Salesforce AI agent response wrapper, extracting JSON content');
            return this.combinePartedResponses(cleanedResponse);
        }
        
        // If no multiple response patterns found, return the cleaned response
        console.log('No multiple response patterns found, returning cleaned response');
        return cleanedResponse;
    }
    
    /**
     * Extracts multiple JSON objects from a response string
     * @param {string} response - The response string
     * @returns {Array} - Array of JSON object strings
     */
    extractMultipleJsonObjects(response) {
        const objects = [];
        let braceCount = 0;
        let startIndex = -1;
        let inString = false;
        let escapeNext = false;
        
        for (let i = 0; i < response.length; i++) {
            const char = response[i];
            
            if (escapeNext) {
                escapeNext = false;
                continue;
            }
            
            if (char === '\\') {
                escapeNext = true;
                continue;
            }
            
            if (char === '"' && !escapeNext) {
                inString = !inString;
            }
            
            if (!inString) {
                if (char === '{') {
                    if (braceCount === 0) {
                        startIndex = i;
                    }
                    braceCount++;
                } else if (char === '}') {
                    braceCount--;
                    if (braceCount === 0 && startIndex !== -1) {
                        const jsonObject = response.substring(startIndex, i + 1);
                        try {
                            // Validate that this is valid JSON
                            JSON.parse(jsonObject);
                            objects.push(jsonObject);
                        } catch (e) {
                            console.log('Invalid JSON object found, skipping:', jsonObject.substring(0, 100));
                        }
                        startIndex = -1;
                    }
                }
            }
        }
        
        return objects;
    }
    
    /**
     * Extracts multiple JSON arrays from a response string
     * @param {string} response - The response string
     * @returns {Array} - Array of JSON array strings
     */
    extractMultipleJsonArrays(response) {
        const arrays = [];
        let bracketCount = 0;
        let startIndex = -1;
        let inString = false;
        let escapeNext = false;
        
        for (let i = 0; i < response.length; i++) {
            const char = response[i];
            
            if (escapeNext) {
                escapeNext = false;
                continue;
            }
            
            if (char === '\\') {
                escapeNext = true;
                continue;
            }
            
            if (char === '"' && !escapeNext) {
                inString = !inString;
            }
            
            if (!inString) {
                if (char === '[') {
                    if (bracketCount === 0) {
                        startIndex = i;
                    }
                    bracketCount++;
                } else if (char === ']') {
                    bracketCount--;
                    if (bracketCount === 0 && startIndex !== -1) {
                        const jsonArray = response.substring(startIndex, i + 1);
                        try {
                            // Validate that this is valid JSON
                            JSON.parse(jsonArray);
                            arrays.push(jsonArray);
                        } catch (e) {
                            console.log('Invalid JSON array found, skipping:', jsonArray.substring(0, 100));
                        }
                        startIndex = -1;
                    }
                }
            }
        }
        
        return arrays;
    }
    
    /**
     * Combines multiple JSON objects into a single response
     * @param {Array} jsonObjects - Array of JSON object strings
     * @returns {string} - Combined JSON response
     */
    combineJsonObjects(jsonObjects) {
        try {
            // Parse all objects and look for schedule-related data
            const schedules = [];
            const otherData = [];
            
            jsonObjects.forEach((objStr, index) => {
                try {
                    const obj = JSON.parse(objStr);
                    console.log(`Parsed object ${index}:`, Object.keys(obj));
                    
                    // Check if this object contains schedule data
                    if (obj.schedule || obj.sessions || obj.proposedSchedule) {
                        schedules.push(obj);
                    } else {
                        otherData.push(obj);
                    }
                } catch (e) {
                    console.log(`Failed to parse object ${index}:`, e.message);
                }
            });
            
            if (schedules.length > 0) {
                // Combine all schedule data
                const combinedSchedule = this.mergeScheduleData(schedules);
                console.log('Combined schedule data:', combinedSchedule);
                return JSON.stringify(combinedSchedule);
            } else {
                // If no schedule data found, return the first valid object
                console.log('No schedule data found, returning first valid object');
                return jsonObjects[0];
            }
        } catch (e) {
            console.log('Failed to combine JSON objects:', e.message);
            return jsonObjects[0] || '';
        }
    }
    
    /**
     * Combines multiple JSON arrays into a single response
     * @param {Array} jsonArrays - Array of JSON array strings
     * @returns {string} - Combined JSON response
     */
    combineJsonArrays(jsonArrays) {
        try {
            // Parse all arrays and combine them
            const allItems = [];
            
            jsonArrays.forEach((arrayStr, index) => {
                try {
                    const array = JSON.parse(arrayStr);
                    console.log(`Parsed array ${index} with ${array.length} items`);
                    allItems.push(...array);
                } catch (e) {
                    console.log(`Failed to parse array ${index}:`, e.message);
                }
            });
            
            console.log(`Combined ${allItems.length} total items from ${jsonArrays.length} arrays`);
            return JSON.stringify(allItems);
        } catch (e) {
            console.log('Failed to combine JSON arrays:', e.message);
            return jsonArrays[0] || '';
        }
    }
    
    /**
     * Combines responses that have explicit part indicators
     * @param {string} response - The response string
     * @returns {string} - Combined response
     */
    combinePartedResponses(response) {
        try {
            // First, try to extract the JSON content from the response
            // This handles cases where the response has text wrapper around JSON
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                console.log('Extracted JSON content from response with text wrapper');
                let jsonContent = jsonMatch[0];
                
                // Fix escaped newlines and other escaped characters
                jsonContent = jsonContent.replace(/\\n/g, '\n');
                jsonContent = jsonContent.replace(/\\t/g, '\t');
                jsonContent = jsonContent.replace(/\\r/g, '\r');
                jsonContent = jsonContent.replace(/\\"/g, '"');
                jsonContent = jsonContent.replace(/\\\\/g, '\\');
                
                console.log('Fixed escaped characters in JSON content');
                return jsonContent;
            }
            
            // If no JSON found, then try to handle explicit part indicators
            const parts = [];
            
            // Split by common part indicators
            const partRegex = /(?:Part\s*\d+|Response\s*\d+)[:\s]*([\s\S]*?)(?=Part\s*\d+|Response\s*\d+|$)/gi;
            let match;
            
            while ((match = partRegex.exec(response)) !== null) {
                const partContent = match[1].trim();
                if (partContent) {
                    parts.push(partContent);
                }
            }
            
            if (parts.length > 1) {
                console.log(`Found ${parts.length} parts with explicit indicators`);
                // Try to combine the parts as JSON
                return this.combineJsonParts(parts);
            }
            
            return response;
        } catch (e) {
            console.log('Failed to combine parted responses:', e.message);
            return response;
        }
    }
    
    /**
     * Combines multiple JSON parts into a single response
     * @param {Array} parts - Array of JSON part strings
     * @returns {string} - Combined JSON response
     */
    combineJsonParts(parts) {
        try {
            const allItems = [];
            
            parts.forEach((part, index) => {
                try {
                    // Try to parse as JSON array
                    const parsed = JSON.parse(part);
                    if (Array.isArray(parsed)) {
                        allItems.push(...parsed);
                    } else if (parsed.schedule || parsed.sessions) {
                        // If it's an object with schedule data, extract the schedule
                        const scheduleData = parsed.schedule || parsed.sessions;
                        if (Array.isArray(scheduleData)) {
                            allItems.push(...scheduleData);
                        }
                    }
                } catch (e) {
                    console.log(`Failed to parse part ${index}:`, e.message);
                }
            });
            
            if (allItems.length > 0) {
                console.log(`Combined ${allItems.length} items from ${parts.length} parts`);
                return JSON.stringify(allItems);
            }
            
            return parts[0] || '';
        } catch (e) {
            console.log('Failed to combine JSON parts:', e.message);
            return parts[0] || '';
        }
    }
    
    /**
     * Checks if a response indicates that more parts are coming
     * @param {string} response - The agent response
     * @returns {boolean} - True if more parts are expected
     */
    responseIndicatesMoreParts(response) {
        if (!response) return false;
        
        console.log('=== responseIndicatesMoreParts called ===');
        console.log('Response length:', response?.length || 0);
        console.log('Response preview:', response?.substring(0, 200));
        console.log('Response end:', response?.substring(Math.max(0, (response?.length || 0) - 200)));
        
        // Check if the response contains explicit part indicators
        const indicators = [
            'Part 1',
            'Part 2 will follow',
            'more parts',
            'will follow',
            'continues in',
            'next part',
            'additional parts'
        ];
        
        const hasIndicator = indicators.some(indicator => 
            response.toLowerCase().includes(indicator.toLowerCase())
        );
        
        if (hasIndicator) {
            console.log('Response contains direct part indicator:', indicators.find(indicator => 
                response.toLowerCase().includes(indicator.toLowerCase())
            ));
            return true;
        }
        
        // Check if this is a Salesforce AI agent response wrapper
        if (response.includes('"type":"Text"') && response.includes('"value":')) {
            console.log('Response is a Salesforce AI agent wrapper, checking content for part indicators');
            
            // Extract the actual content from the wrapper to check for part indicators
            try {
                const wrapper = JSON.parse(response);
                if (wrapper.type === 'Text' && wrapper.value) {
                    const content = wrapper.value;
                    console.log('Extracted content length:', content.length);
                    console.log('Extracted content preview:', content.substring(0, 200));
                    console.log('Extracted content end:', content.substring(Math.max(0, content.length - 200)));
                    
                    const contentHasIndicator = indicators.some(indicator => 
                        content.toLowerCase().includes(indicator.toLowerCase())
                    );
                    
                    if (contentHasIndicator) {
                        const foundIndicator = indicators.find(indicator => 
                            content.toLowerCase().includes(indicator.toLowerCase())
                        );
                        console.log('Content inside wrapper indicates more parts are coming:', foundIndicator);
                        return true;
                    }
                }
            } catch (e) {
                console.log('Failed to parse wrapper to check content for part indicators:', e.message);
            }
        }
        
        console.log('Response does not indicate more parts are coming');
        return false;
    }
    
    /**
     * Waits for all parts of a multi-part response to complete
     * @param {string} firstPartResponse - The first part response
     */
    waitForAllParts(firstPartResponse) {
        console.log('=== waitForAllParts called ===');
        console.log('First part response length:', firstPartResponse?.length || 0);
        console.log('First part preview:', firstPartResponse?.substring(0, 200));
        console.log('First part end:', firstPartResponse?.substring(Math.max(0, (firstPartResponse?.length || 0) - 200)));
        
        // Store the first part
        this.partialResponses = [firstPartResponse];
        this.isWaitingForParts = true;
        this.showAsyncProgress = true;
        this.asyncProgress = 50; // Show progress while waiting
        
        // Continue polling for more parts
        this.continuePollingForParts();
        
        // Show message to user
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Processing Multi-Part Response',
                message: 'The AI agent is sending the schedule in multiple parts. Please wait while we collect all parts...',
                variant: 'info'
            })
        );
    }
    
    /**
     * Continues polling for additional parts of the response
     */
    continuePollingForParts() {
        if (!this.asyncSessionId || !this.isWaitingForParts) return;
        
        console.log('=== continuePollingForParts started ===');
        console.log('Waiting for additional parts from async session:', this.asyncSessionId);
        
        const partPollInterval = setInterval(() => {
            if (!this.asyncSessionId || !this.isWaitingForParts) {
                clearInterval(partPollInterval);
                return;
            }
            
            // Check if the async session has been updated with more content
            getAsyncSchedulingAgentStatus({ asyncSessionId: this.asyncSessionId })
                .then(statusResponse => {
                    console.log('Checking for additional parts:', statusResponse.status);
                    console.log('Current response length:', statusResponse.agentResponse?.length || 0);
                    console.log('First part length:', this.partialResponses[0]?.length || 0);
                    
                    if (statusResponse.status === 'Completed') {
                        // Check if this response has more content than the first part
                        if (statusResponse.agentResponse && 
                            statusResponse.agentResponse.length > this.partialResponses[0].length) {
                            
                            console.log('Found additional content, length increased from', 
                                this.partialResponses[0].length, 'to', statusResponse.agentResponse.length);
                            
                            // Add this response to our collection
                            this.partialResponses.push(statusResponse.agentResponse);
                            
                            // Check if we have all parts now
                            if (this.hasAllParts(statusResponse.agentResponse)) {
                                console.log('All parts received, processing complete response');
                                clearInterval(partPollInterval);
                                this.processCompleteMultiPartResponse();
                            }
                        } else {
                            console.log('No additional content found, response length:', statusResponse.agentResponse?.length || 0);
                            
                            // If the response length hasn't increased but we're still waiting,
                            // check if the content indicates completion
                            if (statusResponse.agentResponse && this.hasAllParts(statusResponse.agentResponse)) {
                                console.log('Response indicates completion, processing complete response');
                                clearInterval(partPollInterval);
                                this.processCompleteMultiPartResponse();
                            }
                        }
                    } else if (statusResponse.status === 'Failed') {
                        clearInterval(partPollInterval);
                        this.handleAsyncAgentFailure(statusResponse);
                    }
                })
                .catch(error => {
                    console.error('Error checking for additional parts:', error);
                });
        }, 15000); // Poll every 15 seconds for additional parts
        
        // Set a timeout to stop waiting for parts
        setTimeout(() => {
            if (this.isWaitingForParts) {
                console.log('Timeout reached while waiting for parts, processing what we have');
                clearInterval(partPollInterval);
                this.processCompleteMultiPartResponse();
            }
        }, 60000); // Wait up to 1 minute for all parts
    }
    
    /**
     * Checks if we have received all parts of the response
     * @param {string} latestResponse - The latest response received
     * @returns {boolean} - True if all parts are received
     */
    hasAllParts(latestResponse) {
        if (!latestResponse) return false;
        
        // Check if the response indicates it's complete
        const completionIndicators = [
            'schedule complete',
            'all sessions included',
            'final part',
            'complete schedule',
            'all parts delivered',
            'this concludes',
            'end of schedule',
            'final schedule'
        ];
        
        const hasCompletionIndicator = completionIndicators.some(indicator => 
            latestResponse.toLowerCase().includes(indicator.toLowerCase())
        );
        
        // Check if the response no longer mentions "more parts will follow"
        const noMorePartsIndicators = [
            'more parts will follow',
            'part 2 will follow',
            'additional parts',
            'continues in'
        ];
        
        const noMorePartsMentioned = !noMorePartsIndicators.some(indicator => 
            latestResponse.toLowerCase().includes(indicator.toLowerCase())
        );
        
        // Also check if the response length has stabilized (no more content being added)
        let lengthStabilized = false;
        if (this.partialResponses.length > 1) {
            const lastTwoLengths = this.partialResponses.slice(-2).map(r => r.length);
            lengthStabilized = lastTwoLengths[0] === lastTwoLengths[1];
        }
        
        const hasAllParts = hasCompletionIndicator || (noMorePartsMentioned && lengthStabilized);
        
        console.log('hasAllParts check:', {
            hasCompletionIndicator,
            noMorePartsMentioned,
            lengthStabilized,
            partialResponsesCount: this.partialResponses.length,
            result: hasAllParts
        });
        
        return hasAllParts;
    }
    
    /**
     * Processes the complete multi-part response
     */
    processCompleteMultiPartResponse() {
        console.log('=== processCompleteMultiPartResponse called ===');
        console.log('Total parts collected:', this.partialResponses.length);
        
        this.isWaitingForParts = false;
        this.showAsyncProgress = false;
        this.asyncProgress = 100;
        
        // Combine all parts into a single response
        const combinedResponse = this.combineMultipleResponses(
            this.partialResponses.join('\n\n--- PART SEPARATOR ---\n\n')
        );
        
        // Process the combined response
        this.handleAgentResponse({
            success: true,
                isChunked: false,
                agentResponse: combinedResponse,
                message: 'Schedule generated successfully (async) - all parts combined'
        });
        
        // Show success message
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Schedule Generated',
                message: 'Your conference schedule has been generated successfully using asynchronous processing with multiple parts combined.',
                variant: 'success'
            })
        );
        
        // Clean up
        this.partialResponses = null;
    }
    
    /**
     * Merges multiple schedule data objects into a single schedule
     * @param {Array} schedules - Array of schedule objects
     * @returns {Object} - Merged schedule object
     */
    mergeScheduleData(schedules) {
        try {
            const mergedSchedule = {
                schedule: [],
                sessions: [],
                totalSessions: 0,
                locations: new Set(),
                timeRange: { start: null, end: null }
            };
            
            schedules.forEach((schedule, index) => {
                console.log(`Processing schedule ${index}:`, Object.keys(schedule));
                
                // Extract schedule items
                const scheduleItems = schedule.schedule || schedule.sessions || schedule.proposedSchedule || [];
                if (Array.isArray(scheduleItems)) {
                    mergedSchedule.schedule.push(...scheduleItems);
                    mergedSchedule.sessions.push(...scheduleItems);
                }
                
                // Extract locations
                if (schedule.locations && Array.isArray(schedule.locations)) {
                    schedule.locations.forEach(location => mergedSchedule.locations.add(location));
                }
                
                // Update total sessions
                if (schedule.totalSessions) {
                    mergedSchedule.totalSessions += schedule.totalSessions;
                }
            });
            
            // Convert Set back to array
            mergedSchedule.locations = Array.from(mergedSchedule.locations);
            
            // Calculate total sessions if not already set
            if (mergedSchedule.totalSessions === 0) {
                mergedSchedule.totalSessions = mergedSchedule.schedule.length;
            }
            
            console.log(`Merged schedule with ${mergedSchedule.schedule.length} sessions and ${mergedSchedule.locations.length} locations`);
            return mergedSchedule;
            
        } catch (e) {
            console.log('Failed to merge schedule data:', e.message);
            return schedules[0] || {};
        }
    }

    /**
     * Parses the agent response to extract the schedule data (frontend version)
     * @param {string} agentResponse - The raw response from the agent
     * @returns {Object} - Parsed schedule data or error information
     */
    parseAgentResponseFrontend(agentResponse) {
        console.log('=== parseAgentResponseFrontend called ===');
        
        try {
            // First, try to extract JSON content from Salesforce AI agent wrapper
            if (agentResponse.includes('"type":"Text"') && agentResponse.includes('"value":')) {
                console.log('Detected Salesforce AI agent wrapper, extracting value field');
                
                // Parse the wrapper to get the value field
                const wrapper = JSON.parse(agentResponse);
                if (wrapper.type === 'Text' && wrapper.value) {
                    let extractedContent = wrapper.value;
                    
                    // Fix escaped characters
                    extractedContent = extractedContent.replace(/\\n/g, '\n');
                    extractedContent = extractedContent.replace(/\\t/g, '\t');
                    extractedContent = extractedContent.replace(/\\r/g, '\r');
                    extractedContent = extractedContent.replace(/\\"/g, '"');
                    extractedContent = extractedContent.replace(/\\\\/g, '\\');
                    
                    console.log('Extracted and fixed content from wrapper');
                    
                    // Look for JSON content in the extracted text
                    const jsonMatch = extractedContent.match(/\{[\s\S]*\}/);
                    if (jsonMatch) {
                        try {
                            const scheduleData = JSON.parse(jsonMatch[0]);
                            console.log('Successfully parsed schedule data from wrapper');
                            
                            // Check for both proposedSchedule (new format) and schedule (fallback)
                            const scheduleArray = scheduleData.proposedSchedule || scheduleData.schedule;
                            if (scheduleArray && Array.isArray(scheduleArray)) {
                                const schedule = scheduleArray;
                                const locations = [...new Set(schedule.map(s => s.location).filter(Boolean))];
                                const timeRange = this.calculateTimeRange(schedule);
                                
                                return {
                                    success: true,
                                    schedule: schedule,
                                    totalSessions: schedule.length,
                                    locations: locations,
                                    timeRange: timeRange,
                                    note: 'Schedule parsed successfully from AI agent wrapper'
                                };
                            }
                        } catch (parseError) {
                            console.error('Failed to parse extracted JSON:', parseError);
                        }
                    }
                }
            }
            
            // Fallback to direct JSON parsing
            try {
                const scheduleData = JSON.parse(agentResponse);
                // Check for both proposedSchedule (new format) and schedule (fallback)
                const scheduleArray = scheduleData.proposedSchedule || scheduleData.schedule;
                if (scheduleArray && Array.isArray(scheduleArray)) {
                    const schedule = scheduleArray;
                    const locations = [...new Set(schedule.map(s => s.location).filter(Boolean))];
                    const timeRange = this.calculateTimeRange(schedule);
                    
                    return {
                        success: true,
                        schedule: schedule,
                        totalSessions: schedule.length,
                        locations: locations,
                        timeRange: timeRange,
                        note: 'Schedule parsed successfully from direct JSON'
                    };
                }
            } catch (parseError) {
                console.error('Failed to parse direct JSON:', parseError);
            }
            
            return {
                success: false,
                error: 'Could not parse schedule data from response',
                note: 'Frontend parsing failed'
            };
            
        } catch (error) {
            console.error('Error in parseAgentResponseFrontend:', error);
            return {
                success: false,
                error: error.message,
                note: 'Frontend parsing error'
            };
        }
    }
    
    /**
     * Parses the agent response to extract the schedule data
     * @param {string} agentResponse - The raw response from the agent
     * @returns {Object} - Parsed schedule data or error information
     */
    parseAgentResponse(agentResponse) {
        console.log('=== parseAgentResponse called ===');
        console.log('Raw response length:', agentResponse?.length || 0);
        console.log('Raw response preview:', agentResponse?.substring(0, 500));
        console.log('Raw response end:', agentResponse?.substring(Math.max(0, (agentResponse?.length || 0) - 200)));
        
        // Check if this looks like multiple responses combined
        if (agentResponse && (agentResponse.includes('}{') || agentResponse.includes(']['))) {
            console.log('Detected potential multiple responses in combined response');
        }
        
        if (!agentResponse) {
            return { 
                success: false, 
                error: 'No response received',
                rawResponse: 'No response',
                note: 'No response received from agent'
            };
        }

        // Check if this is a Salesforce AI agent response wrapper
        if (agentResponse.includes('"type":"Text"') && agentResponse.includes('"value":')) {
            console.log('Detected Salesforce AI agent response wrapper');
            
            try {
                // Parse the entire response as JSON first
                const parsedResponse = JSON.parse(agentResponse);
                console.log('Successfully parsed agent response wrapper:', parsedResponse);
                
                if (parsedResponse.type === 'Text' && parsedResponse.value) {
                    // The value field contains the actual schedule data as a string
                    let extractedContent = parsedResponse.value;
                    
                    console.log('Extracted content length:', extractedContent.length);
                    console.log('Extracted content preview:', extractedContent.substring(0, 200));
                    console.log('Extracted content end:', extractedContent.substring(Math.max(0, extractedContent.length - 200)));
                    
                    // Check if the extracted content looks like JSON
                    if (extractedContent.trim().startsWith('[') || extractedContent.trim().startsWith('{')) {
                        try {
                            const scheduleData = JSON.parse(extractedContent);
                            console.log('Successfully parsed extracted schedule data:', scheduleData);
                            console.log('Schedule data type:', typeof scheduleData);
                            console.log('Schedule data isArray:', Array.isArray(scheduleData));
                            console.log('Schedule data length:', Array.isArray(scheduleData) ? scheduleData.length : 'Not an array');
                            
                            if (Array.isArray(scheduleData) && scheduleData.length > 0) {
                                console.log('First session sample:', scheduleData[0]);
                                console.log('First session keys:', Object.keys(scheduleData[0]));
                            }
                            
                            // Extract useful information
                            const schedule = Array.isArray(scheduleData) ? scheduleData : [scheduleData];
                            const locations = [...new Set(schedule.map(s => s.location).filter(Boolean))];
                            const timeRange = this.calculateTimeRange(schedule);
                            
                            console.log('Extracted schedule array:', schedule);
                            console.log('Extracted locations:', locations);
                            console.log('Extracted timeRange:', timeRange);
                            
                            return {
                                success: true,
                                schedule: schedule,
                                totalSessions: schedule.length,
                                locations: locations,
                                timeRange: timeRange,
                                note: 'Response may be truncated due to platform limits'
                            };
                        } catch (parseError) {
                            console.error('Failed to parse extracted JSON:', parseError);
                            console.error('Parse error details:', parseError.message);
                            console.error('Failed content:', extractedContent.substring(0, 500));
                            
                            // Since the JSON parsing failed, try to extract partial data from the truncated content
                            const partialData = this.extractPartialScheduleData(extractedContent);
                            
                            if (partialData.schedule && partialData.schedule.length > 0) {
                                console.log('Successfully extracted partial data from truncated content:', partialData);
                                return {
                                    success: true,
                                    schedule: partialData.schedule,
                                    totalSessions: partialData.schedule.length,
                                    locations: partialData.locations || [],
                                    timeRange: partialData.timeRange || { start: null, end: null },
                                    note: 'Response was truncated - showing partial data. Some sessions may be incomplete.',
                                    rawResponse: agentResponse,
                                    isPartial: true
                                };
                            } else {
                                return { 
                                    success: false, 
                                    error: 'Invalid JSON format in extracted value and no partial data could be extracted',
                                    rawResponse: extractedContent.substring(0, 500) + '...',
                                    note: 'Response appears to be truncated and could not be parsed'
                                };
                            }
                        }
                    } else {
                        console.log('Extracted content does not appear to be JSON');
                        console.log('Content starts with:', extractedContent.trim().substring(0, 50));
                        
                        // Try to extract partial data anyway
                        const partialData = this.extractPartialScheduleData(extractedContent);
                        
                        if (partialData.schedule && partialData.schedule.length > 0) {
                            console.log('Successfully extracted partial data from non-JSON content:', partialData);
                            return {
                                success: true,
                                schedule: partialData.schedule,
                                totalSessions: partialData.schedule.length,
                                locations: partialData.locations || [],
                                timeRange: partialData.timeRange || { start: null, end: null },
                                note: 'Response was truncated - showing partial data extracted from response.',
                                rawResponse: agentResponse,
                                isPartial: true
                            };
                        } else {
                            return { 
                                success: false, 
                                error: 'Extracted content is not valid JSON and no partial data could be extracted',
                                rawResponse: extractedContent.substring(0, 500) + '...',
                                note: 'Response may be truncated'
                            };
                        }
                    }
                } else {
                    console.log('Response wrapper does not contain expected type or value fields');
                    return { 
                        success: false, 
                        error: 'Response wrapper format is not as expected',
                        rawResponse: agentResponse
                    };
                }
            } catch (wrapperParseError) {
                console.error('Failed to parse agent response wrapper as JSON:', wrapperParseError);
                console.error('Wrapper parse error details:', wrapperParseError.message);
                
                // Fall back to the old manual parsing approach if JSON parsing fails
                console.log('Falling back to manual string parsing...');
                
                // Try to extract the value field content - use a more robust approach
                // Look for the start of the value field and extract everything until the end
                const valueStartIndex = agentResponse.indexOf('"value":');
                if (valueStartIndex !== -1) {
                    // Find the start of the actual content (after the colon and whitespace)
                    let contentStartIndex = valueStartIndex + 8; // length of '"value":'
                    
                    // Skip any whitespace after the colon
                    while (contentStartIndex < agentResponse.length && 
                           (agentResponse[contentStartIndex] === ' ' || agentResponse[contentStartIndex] === '\n' || agentResponse[contentStartIndex] === '\r' || agentResponse[contentStartIndex] === '\t')) {
                        contentStartIndex++;
                    }
                    
                    // The value field contains a JSON string, so we need to find the actual start of the JSON
                    // Look for the opening quote of the JSON string
                    if (agentResponse[contentStartIndex] === '"') {
                        contentStartIndex++; // Skip the opening quote
                    }
                    
                    // Extract from the start of content to the end of the string
                    // Since the response is truncated, we'll take everything from contentStartIndex to the end
                    let extractedContent = agentResponse.substring(contentStartIndex);
                    
                    console.log('Manual extraction - extracted content length:', extractedContent.length);
                    console.log('Manual extraction - extracted content preview:', extractedContent.substring(0, 200));
                    console.log('Manual extraction - extracted content end:', extractedContent.substring(Math.max(0, extractedContent.length - 200)));
                    
                    // Check if the extracted content looks like JSON
                    if (extractedContent.trim().startsWith('[') || extractedContent.trim().startsWith('{')) {
                        try {
                            const scheduleData = JSON.parse(extractedContent);
                            console.log('Successfully parsed manually extracted schedule data:', scheduleData);
                            
                            // Extract useful information
                            const schedule = Array.isArray(scheduleData) ? scheduleData : [scheduleData];
                            const locations = [...new Set(schedule.map(s => s.location).filter(Boolean))];
                            const timeRange = this.calculateTimeRange(schedule);
                            
                            return {
                                success: true,
                                schedule: schedule,
                                totalSessions: schedule.length,
                                locations: locations,
                                timeRange: timeRange,
                                note: 'Response may be truncated due to platform limits (parsed manually)'
                            };
                        } catch (parseError) {
                            console.error('Failed to parse manually extracted JSON:', parseError);
                            
                            // Try to extract partial data
                            const partialData = this.extractPartialScheduleData(extractedContent);
                            
                            if (partialData.schedule && partialData.schedule.length > 0) {
                                return {
                                    success: true,
                                    schedule: partialData.schedule,
                                    totalSessions: partialData.schedule.length,
                                    locations: partialData.locations || [],
                                    timeRange: partialData.timeRange || { start: null, end: null },
                                    note: 'Response was truncated - showing partial data (parsed manually).',
                                    rawResponse: agentResponse,
                                    isPartial: true
                                };
                            } else {
                                return { 
                                    success: false, 
                                    error: 'Manual extraction failed - content is not valid JSON and no partial data could be extracted',
                                    rawResponse: extractedContent.substring(0, 500) + '...',
                                    note: 'Response appears to be truncated and could not be parsed'
                                };
                            }
                        }
                    } else {
                        console.log('Manually extracted content does not appear to be JSON');
                        console.log('Content starts with:', extractedContent.trim().substring(0, 50));
                        
                        // Try to extract partial data anyway
                        const partialData = this.extractPartialScheduleData(extractedContent);
                        
                        if (partialData.schedule && partialData.schedule.length > 0) {
                            return {
                                success: true,
                                schedule: partialData.schedule,
                                totalSessions: partialData.schedule.length,
                                locations: partialData.locations || [],
                                timeRange: partialData.timeRange || { start: null, end: null },
                                note: 'Response was truncated - showing partial data extracted manually.',
                                rawResponse: agentResponse,
                                isPartial: true
                            };
                        } else {
                            return { 
                                success: false, 
                                error: 'Manual extraction failed - content is not valid JSON and no partial data could be extracted',
                                rawResponse: extractedContent.substring(0, 500) + '...',
                                note: 'Response may be truncated'
                            };
                        }
                    }
                } else {
                    console.log('No value field found in response wrapper');
                    return { 
                        success: false, 
                        error: 'No value field found in response wrapper',
                        rawResponse: agentResponse
                    };
                }
            }
        } else {
            console.log('No value field found in response wrapper');
        }

        // If we get here, try to parse the entire response as JSON
        // This handles cases where the response might not have the wrapper
        try {
            const scheduleData = JSON.parse(agentResponse);
            console.log('Successfully parsed entire response as JSON:', scheduleData);
            
            // Check if this looks like schedule data
            if (Array.isArray(scheduleData) && scheduleData.length > 0 && scheduleData[0].sessionName) {
                const schedule = scheduleData;
                const locations = [...new Set(schedule.map(s => s.location).filter(Boolean))];
                const timeRange = this.calculateTimeRange(schedule);
                
                return {
                    success: true,
                    schedule: schedule,
                    totalSessions: schedule.length,
                    locations: locations,
                    timeRange: timeRange,
                    note: 'Schedule data parsed successfully'
                };
            } else {
                return {
                    success: false,
                    error: 'Response does not contain valid schedule data',
                    rawResponse: agentResponse.substring(0, 200) + '...',
                    note: 'Response format not recognized'
                };
            }
        } catch (parseError) {
            console.error('Failed to parse entire response as JSON:', parseError);
            
            // Try to extract partial data from the truncated response
            const partialData = this.extractPartialScheduleData(agentResponse);
            
            if (partialData.schedule && partialData.schedule.length > 0) {
                console.log('Extracted partial schedule data:', partialData);
                return {
                    success: true,
                    schedule: partialData.schedule,
                    totalSessions: partialData.schedule.length,
                    locations: partialData.locations || [],
                    timeRange: partialData.timeRange || { start: null, end: null },
                    note: 'Response was truncated - showing partial data. Some sessions may be incomplete.',
                    rawResponse: agentResponse,
                    isPartial: true
                };
            } else {
                return { 
                    success: false, 
                    error: 'Failed to parse response and no partial data could be extracted',
                    rawResponse: agentResponse.substring(0, 500) + '...',
                    note: 'Response appears to be truncated and could not be parsed'
                };
            }
        }
    }

    /**
     * Attempts to extract partial schedule data from a truncated response
     * @param {string} response - The truncated response string
     * @returns {Object} - Partial schedule data if any can be extracted
     */
    extractPartialScheduleData(response) {
        console.log('=== extractPartialScheduleData called ===');
        console.log('Attempting to extract partial data from truncated response');
        console.log('Response length:', response.length);
        console.log('Response preview:', response.substring(0, 200));
        console.log('Response end:', response.substring(Math.max(0, response.length - 200)));
        
        const partialSessions = [];
        const locations = new Set();
        
        try {
            // First, try to find complete session objects by looking for the pattern:
            // {"sessionName": "...", "speakers": [...], "location": "...", "startTime": "...", "endTime": "..."}
            // We'll look for objects that have all the essential properties
            
            // Clean the response first - remove leading/trailing invalid characters
            let cleanedResponse = response.trim();
            
            // Remove leading characters that aren't valid JSON starters
            while (cleanedResponse.length > 0 && 
                   !cleanedResponse.startsWith('{') && 
                   !cleanedResponse.startsWith('[') && 
                   !cleanedResponse.startsWith('"')) {
                cleanedResponse = cleanedResponse.substring(1);
            }
            
            // Remove trailing characters that aren't valid JSON enders
            while (cleanedResponse.length > 0 && 
                   !cleanedResponse.endsWith('}') && 
                   !cleanedResponse.endsWith(']') && 
                   !cleanedResponse.endsWith('"')) {
                cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length - 1);
            }
            
            if (cleanedResponse !== response) {
                console.log('Cleaned response for partial extraction from', response.length, 'to', cleanedResponse.length, 'characters');
                console.log('Cleaned response preview:', cleanedResponse.substring(0, 200));
            }
            
            // Split the response into potential session objects
            // Look for complete objects that end with }
            const sessionObjects = [];
            let currentObject = '';
            let braceCount = 0;
            let inString = false;
            let escapeNext = false;
            
            for (let i = 0; i < cleanedResponse.length; i++) {
                const char = cleanedResponse[i];
                
                if (escapeNext) {
                    escapeNext = false;
                    continue;
                }
                
                if (char === '\\') {
                    escapeNext = true;
                    continue;
                }
                
                if (char === '"' && !escapeNext) {
                    inString = !inString;
                }
                
                if (!inString) {
                    if (char === '{') {
                        if (braceCount === 0) {
                            // Start of a new object
                            currentObject = '';
                        }
                        braceCount++;
                    } else if (char === '}') {
                        braceCount--;
                        if (braceCount === 0) {
                            // End of a complete object
                            currentObject += char;
                            if (currentObject.trim()) {
                                sessionObjects.push(currentObject.trim());
                            }
                            currentObject = '';
                        }
                    }
                }
                
                if (braceCount > 0) {
                    currentObject += char;
                }
            }
            
            console.log('Found potential session objects:', sessionObjects.length);
            
            // Now try to parse each potential session object
            for (let i = 0; i < sessionObjects.length; i++) {
                try {
                    const sessionStr = sessionObjects[i];
                    console.log(`Attempting to parse session object ${i}:`, sessionStr.substring(0, 100) + '...');
                    
                    // Clean up the session string
                    let cleanSessionStr = sessionStr;
                    
                    // Remove trailing commas and incomplete properties
                    cleanSessionStr = cleanSessionStr.replace(/,\s*}/g, '}');
                    cleanSessionStr = cleanSessionStr.replace(/,\s*$/g, '');
                    
                    // Try to parse the cleaned session
                    const session = JSON.parse(cleanSessionStr);
                    
                    // Validate that this looks like a session with essential properties
                    if (session.sessionName && session.location) {
                        console.log(`Successfully parsed session ${i}:`, session.sessionName);
                        
                        // Ensure all required properties exist with fallbacks
                        const completeSession = {
                            sessionName: session.sessionName,
                            location: session.location,
                            speakers: session.speakers || ['Speaker TBD'],
                            startTime: session.startTime || null,
                            endTime: session.endTime || null,
                            format: session.format || 'Session',
                            focus: session.focus || 'General',
                            sessionAbstract: session.sessionAbstract || session.abstract || 'Session details not available due to truncation'
                        };
                        
                        partialSessions.push(completeSession);
                        locations.add(session.location);
                    }
                } catch (sessionParseError) {
                    console.log(`Failed to parse session object ${i}:`, sessionParseError.message);
                    // Continue with next session
                }
            }
            
            // If we still didn't find any sessions, try a more aggressive approach
            // Look for any object that has at least sessionName
            if (partialSessions.length === 0) {
                console.log('No complete sessions found, trying aggressive extraction...');
                
                // Look for any object with sessionName using regex
                const aggressivePattern = /\{[^}]*"sessionName"[^}]*\}/g;
                const aggressiveMatches = cleanedResponse.match(aggressivePattern);
                
                if (aggressiveMatches) {
                    console.log('Found potential partial session matches:', aggressiveMatches.length);
                    
                    for (let i = 0; i < aggressiveMatches.length; i++) {
                        try {
                            const sessionStr = aggressiveMatches[i];
                            console.log(`Attempting aggressive parse of session ${i}:`, sessionStr.substring(0, 100) + '...');
                            
                            // Try to complete the session object by adding missing properties
                            let completedSessionStr = sessionStr;
                            
                            // If it doesn't end with }, try to complete it
                            if (!completedSessionStr.endsWith('}')) {
                                completedSessionStr += '}';
                            }
                            
                            // Remove trailing commas
                            completedSessionStr = completedSessionStr.replace(/,\s*}/g, '}');
                            
                            // Try to parse
                            const session = JSON.parse(completedSessionStr);
                            
                            // Only add if it has the essential properties
                            if (session.sessionName && session.location) {
                                console.log(`Successfully parsed partial session ${i}:`, session.sessionName);
                                
                                // Ensure all required properties exist
                                const completeSession = {
                                    sessionName: session.sessionName,
                                    location: session.location,
                                    speakers: session.speakers || ['Speaker TBD'],
                                    startTime: session.startTime || null,
                                    endTime: session.endTime || null,
                                    format: session.format || 'Session',
                                    focus: session.focus || 'General',
                                    sessionAbstract: session.sessionAbstract || session.abstract || 'Session details not available due to truncation'
                                };
                                
                                partialSessions.push(completeSession);
                                locations.add(session.location);
                            }
                        } catch (sessionParseError) {
                            console.log(`Failed aggressive parse of session ${i}:`, sessionParseError.message);
                            // Continue with next session
                        }
                    }
                }
            }
            
            console.log('Extracted partial sessions:', partialSessions.length);
            console.log('Extracted locations:', Array.from(locations));
            
            if (partialSessions.length > 0) {
                console.log('Sample extracted session:', partialSessions[0]);
            }
            
            return {
                schedule: partialSessions,
                locations: Array.from(locations),
                timeRange: this.calculateTimeRange(partialSessions)
            };
            
        } catch (error) {
            console.error('Error extracting partial data:', error);
            return {
                schedule: [],
                locations: [],
                timeRange: { start: null, end: null }
            };
        }
    }
    
    /**
     * Calculates the time range for the schedule
     * @param {Array} schedule - Array of schedule items
     * @returns {Object} - Start and end times
     */
    calculateTimeRange(schedule) {
        if (!schedule || schedule.length === 0) {
            return { start: null, end: null };
        }
        
        let earliestStart = null;
        let latestEnd = null;
        
        schedule.forEach(item => {
            if (item.startTime) {
                let startTime;
                if (item.startTime instanceof Date) {
                    startTime = item.startTime;
                } else {
                    startTime = new Date(item.startTime);
                }
                
                if (!isNaN(startTime.getTime())) {
                    if (!earliestStart || startTime < earliestStart) {
                        earliestStart = startTime;
                    }
                }
            }
            
            if (item.endTime) {
                let endTime;
                if (item.endTime instanceof Date) {
                    endTime = item.endTime;
                } else {
                    endTime = new Date(item.endTime);
                }
                
                if (!isNaN(endTime.getTime())) {
                    if (!latestEnd || endTime > latestEnd) {
                        latestEnd = endTime;
                    }
                }
            }
        });
        
        return {
            start: earliestStart,
            end: latestEnd
        };
    }

    /**
     * Getter for formatted schedule information
     */
    get formattedScheduleInfo() {
        if (!this.proposedSchedule || !this.proposedSchedule.success) {
            return {
                totalSessions: 0,
                locations: [],
                timeRange: { start: null, end: null }
            };
        }
        
        return {
            totalSessions: this.proposedSchedule.totalSessions || 0,
            locations: this.proposedSchedule.locations || [],
            timeRange: this.proposedSchedule.timeRange || { start: null, end: null }
        };
    }
    
    /**
     * Getter for formatted schedule with display-ready data
     */
    get formattedScheduleForDisplay() {
        console.log('=== formattedScheduleForDisplay getter called ===');
        console.log('proposedSchedule:', this.proposedSchedule);
        
        if (!this.proposedSchedule || !this.proposedSchedule.success) {
            console.log('Early return - missing required data');
            console.log('proposedSchedule exists:', !!this.proposedSchedule);
            console.log('success:', this.proposedSchedule?.success);
            return [];
        }
        
        const schedule = this.proposedSchedule.schedule;
        console.log('Schedule array:', schedule);
        console.log('Schedule array type:', typeof schedule);
        console.log('Schedule array length:', schedule?.length);
        console.log('Schedule array isArray:', Array.isArray(schedule));
        
        if (!Array.isArray(schedule) || schedule.length === 0) {
            console.log('Schedule is not an array or is empty');
            console.log('Schedule value:', schedule);
            return [];
        }
        
        console.log('Processing schedule items...');
        const result = schedule.map((session, index) => {
            console.log(`Processing session ${index}:`, session);
            
            // Handle both database structure and legacy structure
            const sessionName = session.sessionName || session.name || 'Unnamed Session';
            const location = session.location || 'Unknown Location';
            const speakers = session.speakers || session.speaker || [];
            const format = session.format || 'Unknown Format';
            const focus = session.focus || 'No Focus Specified';
            const sessionAbstract = session.sessionAbstract || session.abstract || 'No abstract available';
            
            // Handle time parsing more robustly
            let startTime = null;
            let endTime = null;
            
            try {
                if (session.startTime) {
                    startTime = new Date(session.startTime);
                    if (isNaN(startTime.getTime())) {
                        console.warn(`Invalid startTime for session ${index}:`, session.startTime);
                        startTime = null;
                    }
                }
                
                if (session.endTime) {
                    endTime = new Date(session.endTime);
                    if (isNaN(endTime.getTime())) {
                        console.warn(`Invalid endTime for session ${index}:`, session.endTime);
                        endTime = null;
                    }
                }
            } catch (timeError) {
                console.error(`Error parsing time for session ${index}:`, timeError);
            }
            
            const formattedSession = {
                sessionName: sessionName,
                location: location,
                displayDate: startTime ? this.formatSessionDate(startTime) : 'No Date',
                displayStartTime: startTime ? this.formatSessionTime(startTime) : 'No Start Time',
                displayEndTime: endTime ? this.formatSessionTime(endTime) : 'No End Time',
                displayTime: startTime && endTime ? 
                    `${this.formatSessionTime(startTime)} - ${this.formatSessionTime(endTime)}` : 
                    'No Time',
                displayDuration: startTime && endTime ? 
                    this.formatDuration(this.getSessionDuration(startTime, endTime)) : 
                    'No Duration',
                displaySpeakers: this.formatSpeakersForDisplay(speakers),
                format: format,
                focus: focus,
                sessionAbstract: sessionAbstract
            };
            
            console.log(`Formatted session ${index}:`, formattedSession);
            return formattedSession;
        });
        
        console.log('Final formatted result:', result);
        console.log('Final result length:', result.length);
        return result;
    }
    
    /**
     * Format speakers array for display in the table
     * @param {Array} speakers - Array of speaker names or speaker objects
     * @returns {string} - Formatted speaker string
     */
    formatSpeakersForDisplay(speakers) {
        if (!speakers || !Array.isArray(speakers)) {
            return 'TBD';
        }
        
        // Handle both string arrays and object arrays from database
        const speakerNames = speakers.map(speaker => {
            if (typeof speaker === 'string') {
                return speaker;
            } else if (speaker && typeof speaker === 'object') {
                // Database structure: { firstName, lastName, email, fullName }
                return speaker.fullName || `${speaker.firstName || ''} ${speaker.lastName || ''}`.trim() || 'Unknown Speaker';
            }
            return 'Unknown Speaker';
        });
        
        return speakerNames.join(', ');
    }
    
    /**
     * Handle table sorting
     * @param {Object} event - Sort event from lightning-datatable
     */
    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
    }
    
    /**
     * Formats a session date for display
     * @param {string} timeString - ISO time string
     * @returns {string} - Formatted date string
     */
    formatSessionDate(date) {
        if (!date) return 'No Date';
        
        try {
            // If date is already a Date object, use it directly
            if (date instanceof Date) {
                return date.toLocaleDateString('en-US', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                });
            }
            
            // If date is a string, parse it
            const dateObj = new Date(date);
            if (isNaN(dateObj.getTime())) {
                return 'Invalid Date';
            }
            
            return dateObj.toLocaleDateString('en-US', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        } catch (error) {
            console.error('Error formatting session date:', error);
            return 'Date Error';
        }
    }
    
    /**
     * Getter to check if schedule has parsing errors
     */
    get hasScheduleError() {
        return !this.proposedSchedule || 
               !this.proposedSchedule.success || 
               this.proposedSchedule.error ||
               !this.proposedSchedule.schedule || 
               this.proposedSchedule.schedule.length === 0;
    }
    
    /**
     * Getter for schedule error message
     */
    get scheduleErrorMessage() {
        if (!this.proposedSchedule) {
            return 'No schedule data available';
        }
        
        if (this.proposedSchedule.error) {
            return this.proposedSchedule.error;
        }
        
        if (!this.proposedSchedule.success) {
            return this.proposedSchedule.message || 'Schedule generation failed';
        }
        
        if (!this.proposedSchedule.schedule || this.proposedSchedule.schedule.length === 0) {
            return 'No sessions found in the schedule';
        }
        
        return null;
    }

    /**
     * Getter for formatted locations display
     */
    get formattedLocationsDisplay() {
        if (!this.proposedSchedule || !this.proposedSchedule.success || !this.proposedSchedule.locations) {
            return 'No locations available';
        }
        
        const locations = this.proposedSchedule.locations;
        if (locations.length === 0) {
            return 'No locations available';
        }
        
        if (locations.length === 1) {
            return locations[0];
        }
        
        if (locations.length === 2) {
            return `${locations[0]} and ${locations[1]}`;
        }
        
        const lastLocation = locations[locations.length - 1];
        const otherLocations = locations.slice(0, -1);
        return `${otherLocations.join(', ')}, and ${lastLocation}`;
    }

    /**
     * Returns true if there's no schedule data to display
     */
    get hasNoScheduleData() {
        return !this.proposedSchedule || 
               !this.proposedSchedule.success || 
               !this.proposedSchedule.schedule || 
               this.proposedSchedule.schedule.length === 0;
    }

    /**
     * Returns a message explaining why no data is shown
     */
    get noDataMessage() {
        if (!this.proposedSchedule) {
            return 'No schedule data available. Please generate a schedule first.';
        }
        
        if (!this.proposedSchedule.success) {
            return this.proposedSchedule.error || 'Failed to generate schedule.';
        }
        
        if (!this.proposedSchedule.schedule || this.proposedSchedule.schedule.length === 0) {
            if (this.proposedSchedule.note && this.proposedSchedule.note.includes('truncated')) {
                return 'The response was truncated and no complete session data could be extracted. Please try again or contact support.';
            }
            return 'No sessions found in the schedule.';
        }
        
        return 'No schedule data available.';
    }
    
    get showAsyncControls() {
        return this.isAsyncMode && this.asyncSessionId;
    }
    
    get isAsyncFailed() {
        return this.asyncStatus === 'Failed';
    }
    
    get asyncStatusDisplay() {
        if (!this.asyncStatus) return '';
        
        switch (this.asyncStatus) {
            case 'Pending':
                return 'Queued for processing';
            case 'Processing':
                return 'Currently processing';
            case 'Completed':
                return 'Completed successfully';
            case 'Failed':
                return 'Failed';
            case 'Cancelled':
                return 'Cancelled';
            default:
                return this.asyncStatus;
        }
    }
    
    get asyncProgressBarStyle() {
        return `width: ${this.asyncProgress}%`;
    }

    /**
     * Formats a session time for display
     * @param {string} timeString - ISO time string
     * @returns {string} - Formatted time string
     */
    formatSessionTime(date) {
        if (!date) return 'No Time';
        
        try {
            // If date is already a Date object, use it directly
            if (date instanceof Date) {
                return date.toLocaleTimeString('en-US', {
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: true
                });
            }
            
            // If date is a string, parse it
            const dateObj = new Date(date);
            if (isNaN(dateObj.getTime())) {
                return 'Invalid Time';
            }
            
            return dateObj.toLocaleTimeString('en-US', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });
        } catch (error) {
            console.error('Error formatting session time:', error);
            return 'Time Error';
        }
    }
    
    /**
     * Calculates session duration in minutes
     * @param {string} startTime - Session start time
     * @param {string} endTime - Session end time
     * @returns {number} - Duration in minutes
     */
    getSessionDuration(startTime, endTime) {
        if (!startTime || !endTime) return 0;
        
        try {
            let startDate, endDate;
            
            // If times are already Date objects, use them directly
            if (startTime instanceof Date && endTime instanceof Date) {
                startDate = startTime;
                endDate = endTime;
            } else {
                // If times are strings, parse them
                startDate = new Date(startTime);
                endDate = new Date(endTime);
                
                if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
                    return 0;
                }
            }
            
            const durationMs = endDate.getTime() - startDate.getTime();
            const durationMinutes = Math.round(durationMs / (1000 * 60));
            
            return Math.max(0, durationMinutes);
        } catch (error) {
            console.error('Error calculating session duration:', error);
            return 0;
        }
    }
    
    /**
     * Formats session duration for display
     * @param {number} durationMinutes - Duration in minutes
     * @returns {string} - Formatted duration string
     */
    formatDuration(durationMinutes) {
        if (durationMinutes < 60) {
            return `${durationMinutes} min`;
        } else {
            const hours = Math.floor(durationMinutes / 60);
            const minutes = durationMinutes % 60;
            if (minutes === 0) {
                return `${hours} hr`;
            } else {
                return `${hours} hr ${minutes} min`;
            }
        }
    }

    handleAcceptSchedule() {
        // TODO: Implement logic to accept and save the proposed schedule
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Schedule Accepted',
                message: 'The proposed schedule has been accepted and saved.',
                variant: 'success'
            })
        );
        
        // Navigate to next step or reset form
        this.resetForm();
    }

    handleRejectSchedule() {
        this.showResults = false;
        this.proposedSchedule = null;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Schedule Rejected',
                message: 'The proposed schedule has been rejected. You can try again.',
                variant: 'info'
            })
        );
    }

    handleTryAgain() {
        this.showResults = false;
        this.proposedSchedule = null;
        if (this.isAsyncMode) {
            this.buildProposedScheduleAsync();
        } else {
            this.buildProposedSchedule();
        }
    }
    
    handleCancelAsync() {
        if (this.asyncSessionId) {
            // Note: In a real implementation, you would call a cancel method
            // For now, we'll just reset the form
            console.log('Cancelling async session:', this.asyncSessionId);
        }
        
        this.resetForm();
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Async Session Cancelled',
                message: 'The asynchronous schedule generation has been cancelled.',
                variant: 'info'
            })
        );
    }
    
    handleRetryAsync() {
        if (this.asyncSessionId) {
            console.log('Retrying async session:', this.asyncSessionId);
            
            // Reset the async state for retry
            this.asyncStatus = 'Pending';
            this.asyncProgress = 0;
            this.errorMessage = '';
            
            // Show loading state
            this.isLoading = true;
            
            // Call the retry method (you would need to implement this in the controller)
            // For now, we'll just show a message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Retry Initiated',
                    message: 'Retrying the asynchronous schedule generation...',
                    variant: 'info'
                })
            );
            
            // Reset loading state
            this.isLoading = false;
        }
    }

    handleModifySchedule() {
        console.log('Handling schedule modification for event:', this.selectedEventId);
        // Add your modification logic here
        this.showSuccessMessage('Schedule modification initiated!');
    }

    resetForm() {
        this.selectedOption = '';
        this.selectedEventId = '';
        this.errorMessage = '';
        this.isAsyncMode = false;
        this.asyncSessionId = null;
        this.asyncStatus = null;
        this.asyncProgress = 0;
        this.showAsyncProgress = false;
        this.isWaitingForParts = false;
        this.partialResponses = null;
        
        // Clean up any active intervals
        this.cleanupAsyncIntervals();
    }
    
    cleanupAsyncIntervals() {
        if (this.pollIntervalId) {
            clearInterval(this.pollIntervalId);
            this.pollIntervalId = null;
        }
        if (this.progressIntervalId) {
            clearInterval(this.progressIntervalId);
            this.progressIntervalId = null;
        }
    }
    
    disconnectedCallback() {
        // Clean up intervals when component is destroyed
        this.cleanupAsyncIntervals();
    }

    showSuccessMessage(message) {
        // You can implement a toast notification or success message here
        console.log(message);
        // Example: this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: message, variant: 'success' }));
    }

    /**
     * Debug method to log schedule information
     */
    logScheduleDebugInfo() {
        console.log('=== Schedule Debug Information ===');
        
        if (!this.proposedSchedule) {
            console.log('proposedSchedule is null or undefined');
            return;
        }
        
        console.log('proposedSchedule structure:', this.proposedSchedule);
        console.log('Success:', this.proposedSchedule.success);
        console.log('Message:', this.proposedSchedule.message);
        console.log('Error:', this.proposedSchedule.error);
        console.log('Note:', this.proposedSchedule.note); // Log the new note field
        
        if (this.proposedSchedule.schedule) {
            console.log('Schedule Array Length:', this.proposedSchedule.schedule.length);
            console.log('Schedule Array:', this.proposedSchedule.schedule);
            
            if (this.proposedSchedule.schedule.length > 0) {
                console.log('First Session Sample:', this.proposedSchedule.schedule[0]);
                console.log('Session Keys:', Object.keys(this.proposedSchedule.schedule[0]));
            }
        } else {
            console.log('Schedule array is null or undefined');
        }
        
        console.log('Total Sessions:', this.proposedSchedule.totalSessions);
        console.log('Locations:', this.proposedSchedule.locations);
        console.log('Time Range:', this.proposedSchedule.timeRange);
        
        if (this.formattedScheduleForDisplay) {
            console.log('Formatted Schedule for Display Length:', this.formattedScheduleForDisplay.length);
            console.log('Formatted Schedule for Display:', this.formattedScheduleForDisplay);
        }
        
        console.log('=== End Schedule Debug Information ===');
    }

    /**
     * @description Queries the database for scheduled sessions to display in the UI
     */
    async queryScheduledSessions() {
        try {
            console.log('Querying database for scheduled sessions...');
            
            // Call the Apex method to get scheduled sessions
            const scheduledSessions = await getScheduledSessions({ eventId: this.selectedEventId });
            console.log('Retrieved scheduled sessions:', scheduledSessions);
            
            if (scheduledSessions && scheduledSessions.length > 0) {
                // Update the proposedSchedule with real data from the database
                this.proposedSchedule = {
                    success: true,
                    schedule: scheduledSessions,
                    totalSessions: scheduledSessions.length,
                    locations: [...new Set(scheduledSessions.map(s => s.location).filter(Boolean))],
                    timeRange: this.calculateTimeRange(scheduledSessions),
                    message: `Successfully retrieved ${scheduledSessions.length} scheduled sessions from database`,
                    error: null,
                    note: 'Schedule data retrieved from database'
                };
                
                console.log('Updated proposedSchedule with database data:', this.proposedSchedule);
            } else {
                console.log('No scheduled sessions found in database');
                // Keep the existing success message but indicate no sessions found
                this.proposedSchedule.note = 'Agent reported success but no sessions were found in database. Sessions may still be processing.';
            }
            
        } catch (error) {
            console.error('Error querying scheduled sessions:', error);
            // Keep the existing success message but add error note
            this.proposedSchedule.note = `Agent reported success but failed to retrieve sessions from database: ${error.message}`;
        }
    }
}