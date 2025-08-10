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
            // Prepare the input for the Scheduling_Agent_1
            const agentInput = {
                eventId: this.selectedEventId || this.eventId,
                action: 'buildProposedSchedule',
                context: {
                    selectedOption: this.selectedOption,
                    timestamp: new Date().toISOString()
                }
            };
            
            // Invoke the Scheduling_Agent_1 agent
            this.invokeSchedulingAgent(agentInput);
            
        } catch (error) {
            console.error('Error in buildProposedSchedule:', error);
            this.errorMessage = 'Failed to build proposed schedule. Please try again.';
            this.isLoading = false;
        }
    }

    async invokeSchedulingAgent(agentInput) {
        try {
            console.log('Invoking Scheduling_Agent_1 with input:', agentInput);
            // Call the Apex method to invoke the Scheduling_Agent_1
            const result = await invokeSchedulingAgent({
                eventId: agentInput.eventId,
                context: JSON.stringify(agentInput.context)
            });
            
            console.log('Scheduling_Agent_1 response:', result);
            
            // Handle the agent response
            this.handleAgentResponse({
                success: result.success,
                message: result.message,
                data: result
            });
            
        } catch (error) {
            console.error('Error invoking Scheduling_Agent_1:', error);
            this.handleAgentResponse({
                success: false,
                message: 'Failed to invoke Scheduling_Agent_1: ' + (error.body?.message || error.message),
                error: error.body?.message || error.message
            });
        }
    }

    handleAgentResponse(response) {
        this.isLoading = false;
        
        if (response.success) {
            // Store the proposed schedule
            this.proposedSchedule = response;
            this.showResults = true;
            
            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: response.message,
                    variant: 'success'
                })
            );
        } else {
            // Show error message
            this.errorMessage = response.message;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: response.message,
                    variant: 'error'
                })
            );
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
}