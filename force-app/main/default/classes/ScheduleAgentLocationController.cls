
/**
 * @description ScheduleAgentLocationController is an Apex class that provides an InvocableMethod
 *      to load rooms with availability slots for scheduling. It currently only loads the Location records
 *      and the availability will be added later.
 * @Version: 1.0
 */
public with sharing class ScheduleAgentLocationController {

    /**
     * @description This method is used to load rooms with availability slots for scheduling.
     * It currently only loads the Location records and the availability will be added later.
     * @Version: 1.0
     * @param input:input InvocableMethods called by Agentforce must have an input parameter, we don't actually need any kind of input for this method so it's value is not used.
     * @return: A list of LocationArray objects containing the loaded rooms and their availability slots.
     * @throws: None
     */
    @InvocableMethod(
        label='Load Rooms with availability slots'
        description='Currently just loads Locations, Availbility will be added later'
    )
    public static List<ScheduleAgentLocationController.LocationArray> getLocations(List < ScheduleAgentLocationController.SessionInput > input) {
        List < Session_Location__c > locations = [SELECT Id, Name, Room_Size__c FROM Session_Location__c];

        List < ScheduleAgentLocationController.Location > locationsToReturn = new List < ScheduleAgentLocationController.Location > ();

        System.debug('Location sobjs: ' + JSON.serialize(locations));

        for (Session_Location__c location: locations) {
            ScheduleAgentLocationController.Location loc = new ScheduleAgentLocationController.Location(location.Name, location.Id, location.Room_Size__c);
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

        public Location (String locationName, Id locationId, String locationRoomSize) {
            this.locationName = locationName;
            this.locationId = locationId;
            this.locationCapacity = locationRoomSize;
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