public with sharing class ScheduleAgentLocationController {
    @InvocableMethod(
        label='Load Rooms with availability slots'
        description='Currently just loads Locations, Availbility will be added later'
    )
    public static List<ScheduleAgentLocationController.Location> getLocations(List < ScheduleAgentLocationController.SessionInput > input) {
        List < Session_Location__c > locations = [SELECT Id, Name, Room_Capacity__c FROM Session_Location__c];

        List < ScheduleAgentLocationController.Location > locationsToReturn = new List < ScheduleAgentLocationController.Location > ();
        
        for (Session_Location__c location: locations) {
            ScheduleAgentLocationController.Location loc = new ScheduleAgentLocationController.Location(location.Name, location.Id, String.valueOf(location.Room_Capacity__c));
            System.debug('loc'+JSON.serialize(loc));
            locationsToReturn.add(loc);
        }
        System.debug('Locations to Schedule: ' + JSON.serialize(locationsToReturn));
        return locationsToReturn;
        
        // return locationsToReturn;
    }

    public class Location {
        @InvocableVariable(
            description='Location Name'
        )
        public String locationName;

        @InvocableVariable(
            description='Location Record Id'
        )
        public Id locationId;

        @InvocableVariable(
            description='Location Capacity'
        )
        public String locationCapacity;

        public Location (String locationName, Id locationId, String locationCapacity) {
            this.locationName = locationName;
            this.locationId = locationId;
            this.locationCapacity = locationCapacity;
        }

    }

    public class SessionInput {
        @InvocableVariable(
            description='Useless required variable'
        )
        public String useless;

        public SessionInput() {
            
        }

    }
}