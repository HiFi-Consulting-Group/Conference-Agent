List < ScheduleAgentLocationController.SessionInput > sessions = new List < ScheduleAgentLocationController.SessionInput > ();

List<ScheduleAgentLocationController.Location> locations = ScheduleAgentLocationController.getLocations(sessions);
System.debug('locations: ' + JSON.serialize(locations));
 
List < Session_Slot__c > sessionSlots = ScheduleAgentLocationController.getSessionSlots(sessions);
delete sessionSlots;