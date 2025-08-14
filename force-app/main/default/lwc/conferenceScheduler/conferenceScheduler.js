import { LightningElement, api, track } from 'lwc';
import getEvents from '@salesforce/apex/ScheduleAgentController.getEvents';
import invokeSchedulingAgent from '@salesforce/apex/ScheduleAgentController.invokeSchedulingAgent';
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
        { label: 'Create New Conference Schedule', value: 'new' },
        { label: 'Modify Existing Conference Schedule', value: 'modify' }
    ];

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
        return this.selectedOption === 'new';
    }

    get hasEvents() {
        return this.events && this.events.length > 0;
    }

    get eventOptions() {
        return this.events.map(event => ({
            label: `${event.Name} (${this.formatDate(event.Event_Start_Date__c)} - ${this.formatDate(event.Event_End_Date__c)})`,
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
        if (this.selectedOption === 'new') {
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
        if (this.selectedOption === 'new') {
            this.buildProposedSchedule();
        } else if (this.selectedOption === 'modify') {
            this.handleModifySchedule();
        }
    }

    handleCancel() {
        this.resetForm();
    }

    buildProposedSchedule() {
        this.isLoading = true;
        this.errorMessage = '';
        
        try {
            // Simple message for the agent
            const userMessage = 'Generate a proposed schedule for the conference with available rooms and time slots.';
            
            console.log('Calling schedule agent with message:', userMessage);
            
            // Call the Apex method to invoke the scheduling agent
            invokeSchedulingAgent({ userMessage: userMessage })
                .then(response => {
                    console.log('Agent response:', response);
                    this.handleAgentResponse(response);
                })
                .catch(error => {
                    console.error('Error calling schedule agent:', error);
                    this.isLoading = false;
                    this.errorMessage = error.body?.message || error.message || 'Failed to call schedule agent';
                });
            
        } catch (error) {
            console.error('Error in buildProposedSchedule:', error);
            this.errorMessage = 'Failed to build proposed schedule. Please try again.';
            this.isLoading = false;
        }
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
     * Parses the agent response to extract the schedule data
     * @param {string} agentResponse - The raw response from the agent
     * @returns {Object} - Parsed schedule data or error information
     */
    parseAgentResponse(agentResponse) {
        console.log('=== parseAgentResponse called ===');
        console.log('Raw response preview:', agentResponse?.substring(0, 500));
        console.log('Raw response end:', agentResponse?.substring(Math.max(0, (agentResponse?.length || 0) - 200)));
        
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
            
            // Split the response into potential session objects
            // Look for complete objects that end with }
            const sessionObjects = [];
            let currentObject = '';
            let braceCount = 0;
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
                const aggressiveMatches = response.match(aggressivePattern);
                
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
            
            // Handle both possible property names for session name
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
     * @param {Array} speakers - Array of speaker names
     * @returns {string} - Formatted speaker string
     */
    formatSpeakersForDisplay(speakers) {
        if (!speakers || !Array.isArray(speakers)) {
            return 'TBD';
        }
        return speakers.join(', ');
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
        this.buildProposedSchedule();
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
}