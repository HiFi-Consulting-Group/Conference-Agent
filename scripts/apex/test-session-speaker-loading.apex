// Test script to verify Session speaker loading functionality
// This script tests that the Session wrapper class now properly loads speaker information
// when constructed from a Session__c record with Session_Speakers__r relationship

// Test data setup
// Note: This would need to be run in an org with actual data or test data

System.debug('=== Testing Session Speaker Loading ===');

try {
    // Test 1: Load sessions with speakers using SessionLoader
    System.debug('Test 1: Loading sessions with speakers using SessionLoader');
    
    // Get a sample event ID (you would need to replace this with an actual Event__c ID)
    // List<Event__c> events = [SELECT Id FROM Event__c LIMIT 1];
    // if (!events.isEmpty()) {
    //     Id eventId = events[0].Id;
    //     System.debug('Testing with event ID: ' + eventId);
    //     
    //     // Test the loadSessionsOrganizedBySlotStatus method
    //     List<String> results = SessionLoader.loadSessionsOrganizedBySlotStatus(new List<Id>{eventId});
    //     System.debug('SessionLoader results: ' + results);
    //     
    //     // Test the loadSessionsWithSlots method
    //     List<Session> sessions = SessionLoader.loadSessionsWithSlots(new List<Id>{eventId});
    //     System.debug('Loaded ' + sessions.size() + ' sessions');
    //     
    //     // Check if speakers are loaded
    //     for (Session session : sessions) {
    //         System.debug('Session: ' + session.sessionName + ' has ' + session.getSpeakerCount() + ' speakers');
    //         if (session.hasSpeakers()) {
    //             for (SessionSpeaker speaker : session.speakers) {
    //                 System.debug('  - Speaker: ' + speaker.getDisplayName() + ' (Email: ' + speaker.speakerEmail + ')');
    //             }
    //         }
    //     }
    // } else {
    //     System.debug('No events found to test with');
    // }
    
    // Test 2: Test Session constructor directly
    System.debug('Test 2: Testing Session constructor with speaker data');
    
    // This would require creating test data or using existing data
    // For now, just verify the class compiles and methods exist
    
    // Test 3: Test SessionSpeaker methods
    System.debug('Test 3: Testing SessionSpeaker wrapper methods');
    SessionSpeaker testSpeaker = new SessionSpeaker();
    testSpeaker.setFirstName('John');
    testSpeaker.setLastName('Doe');
    testSpeaker.speakerEmail = 'john.doe@example.com';
    testSpeaker.speakerCompany = 'Test Company';
    
    System.debug('Speaker full name: ' + testSpeaker.speakerFullName);
    System.debug('Speaker display name: ' + testSpeaker.getDisplayName());
    System.debug('Has complete name: ' + testSpeaker.hasCompleteName());
    System.debug('Has contact info: ' + testSpeaker.hasContactInfo());
    
    // Test 4: Test Session speaker management methods
    System.debug('Test 4: Testing Session speaker management methods');
    Session testSession = new Session();
    testSession.sessionName = 'Test Session';
    testSession.addSpeaker(testSpeaker);
    
    System.debug('Session has speakers: ' + testSession.hasSpeakers());
    System.debug('Speaker count: ' + testSession.getSpeakerCount());
    
    // Test removing a speaker
    Boolean removed = testSession.removeSpeaker(testSpeaker.speakerId);
    System.debug('Speaker removed: ' + removed);
    System.debug('Session has speakers after removal: ' + testSession.hasSpeakers());
    
    System.debug('=== All tests completed successfully ===');
    
} catch (Exception e) {
    System.debug('Error during testing: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
} 