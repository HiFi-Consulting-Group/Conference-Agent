import { LightningElement, api, track, wire } from 'lwc';
import getEvents from '@salesforce/apex/ScheduleAgentController.getEvents';

export default class SessionScheduler extends LightningElement {
    @api eventId;
    @track isLoading = false;
    @track errorMessage = '';
    @track selectedOption = '';
    @track selectedEventId = '';
    @track isLoadingEvents = false;
    @track events = [];
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
            // Handle creating new schedule
            this.dispatchEvent(new CustomEvent('flownext'));
            this.buildProposedSchedule();
        } else if (this.selectedOption === 'modify') {
            // Handle modifying existing schedule
            this.dispatchEvent(new CustomEvent('flownext'));
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('flowprevious'));
    }

    // Method to handle flow navigation
    @api
    handleFlowNavigation(action) {
        if (action === 'next') {
            this.dispatchEvent(new CustomEvent('flownext'));
        } else if (action === 'previous') {
            this.dispatchEvent(new CustomEvent('flowprevious'));
        } else if (action === 'finish') {
            this.dispatchEvent(new CustomEvent('flowfinish'));
        }
    }

    // Method to get component data for flow
    @api
    getComponentData() {
        return {
            eventId: this.eventId,
            selectedOption: this.selectedOption,
            selectedEventId: this.selectedEventId,
            // Add any other data you want to pass back to the flow
        };
    }

    // Method to validate component state
    @api
    validate() {
        if (this.selectedOption === 'new') {
            return this.selectedEventId !== '';
        }
        return this.selectedOption !== '';
    }

    buildProposedSchedule() {
        
    }
}