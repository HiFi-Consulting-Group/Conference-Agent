public with sharing class ScheduleAgentLocationController {
    @InvocableMethod(
        label='Load Rooms with availability slots'
        description='Currently just loads Locations, Availbility will be added later'
    )
    public static List<ScheduleAgentLocationController.LocationArray> getLocations(List < ScheduleAgentLocationController.SessionInput > input) {
        List < Session_Location__c > locations = [SELECT Id, Name, Room_Capacity__c FROM Session_Location__c];

        List < ScheduleAgentLocationController.Location > locationsToReturn = new List < ScheduleAgentLocationController.Location > ();

        System.debug('Location sobjs: ' + JSON.serialize(locations));

        for (Session_Location__c location: locations) {
            ScheduleAgentLocationController.Location loc = new ScheduleAgentLocationController.Location(location.Name, location.Id);
            System.debug('loc'+JSON.serialize(loc));
            locationsToReturn.add(loc);
        }

        LocationArray locationsArray = new LocationArray(locationsToReturn);
        //List of results for formatting reasons
        List<LocationArray> locationsArrayAsList = new List<LocationArray>();
        locationsArrayAsList.add(locationsArray);
        System.debug('Locations to Schedule: ' + JSON.serialize(locationsArrayAsList));
        return locationsArrayAsList;
        
        // return locationsToReturn;
    }

    public class LocationArray {
        @InvocableVariable(
            description='Location Array'
        )
        public List<Location> locationArray;

        public LocationArray(List<Location> locationArray) {
            this.locationArray = locationArray;
        }
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

        public Location (String locationName, Id locationId) {
            this.locationName = locationName;
            this.locationId = locationId;
            // this.locationCapacity = locationCapacity;
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