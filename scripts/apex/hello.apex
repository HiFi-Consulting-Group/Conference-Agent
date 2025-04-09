List < ScheduleAgentLocationController.SessionInput > sessions = new List < ScheduleAgentLocationController.SessionInput > ();

List<ScheduleAgentLocationController.Location> locations = ScheduleAgentLocationController.getLocations(sessions);
System.debug('locations: ' + JSON.serialize(locations));
 
List < Session_Slot__c > sessionSlots = ScheduleAgentLocationController.getSessionSlots(sessions);
delete sessionSlots;





//Create Contact records for Speakers with culturally consistent names
List<Contact> speakerContactRecords = new List<Contact>();

// Arrays of names organized by cultural background
Map<String, List<String>> culturalFirstNames = new Map<String, List<String>> {
    'Arabic' => new List<String> {'Aisha', 'Fatima', 'Muhammad', 'Ahmed', 'Yusuf', 'Layla', 'Zainab', 'Omar', 'Ali', 'Hassan'},
    'Chinese' => new List<String> {'Wei', 'Jing', 'Li', 'Chen', 'Xiao', 'Mei', 'Yan', 'Jun', 'Hui', 'Xin'},
    'Japanese' => new List<String> {'Hiroshi', 'Yuki', 'Haruto', 'Sakura', 'Aoi', 'Kenji', 'Mika', 'Takashi', 'Emi', 'Ryo'},
    'Indian' => new List<String> {'Priya', 'Arjun', 'Aarav', 'Ananya', 'Vihaan', 'Lakshmi', 'Rahul', 'Meera', 'Kiran', 'Rohan'},
    'Hispanic' => new List<String> {'Maria', 'Jose', 'Carlos', 'Ana', 'Juan', 'Sofia', 'Diego', 'Valeria', 'Gabriel', 'Camila'},
    'Western' => new List<String> {'James', 'Emma', 'Liam', 'Olivia', 'Noah', 'Ava', 'Ethan', 'Isabella', 'Mason', 'Sophia'},
    'African' => new List<String> {'Kwame', 'Amani', 'Zuri', 'Jabari', 'Nia', 'Kofi', 'Aisha', 'Tunde', 'Zola', 'Kwasi'}
};

Map<String, List<String>> culturalLastNames = new Map<String, List<String>> {
    'Arabic' => new List<String> {'Al-Mansoor', 'Al-Farsi', 'Al-Hashemi', 'Al-Najjar', 'Al-Rashid', 'Al-Saadi', 'Al-Zaabi', 'Al-Qasimi', 'Al-Mazrouei', 'Al-Shamsi'},
    'Chinese' => new List<String> {'Wang', 'Li', 'Zhang', 'Liu', 'Chen', 'Yang', 'Huang', 'Zhao', 'Wu', 'Zhou'},
    'Japanese' => new List<String> {'Sato', 'Suzuki', 'Takahashi', 'Tanaka', 'Watanabe', 'Ito', 'Yamamoto', 'Nakamura', 'Kobayashi', 'Kato'},
    'Indian' => new List<String> {'Patel', 'Shah', 'Singh', 'Kumar', 'Gupta', 'Sharma', 'Verma', 'Malik', 'Khan', 'Ahmed'},
    'Hispanic' => new List<String> {'Gonzalez', 'Rodriguez', 'Gomez', 'Fernandez', 'Lopez', 'Martinez', 'Sanchez', 'Perez', 'Martin', 'Garcia'},
    'Western' => new List<String> {'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez'},
    'African' => new List<String> {'Okafor', 'Adebayo', 'Nwosu', 'Ogunleye', 'Adeleke', 'Obi', 'Okonkwo', 'Adeyemi', 'Okafor', 'Ogunjimi'}
};

// List of cultural backgrounds
List<String> cultures = new List<String>(culturalFirstNames.keySet());

// Generate 150 contact records
for (Integer i = 0; i < 150; i++) {
    // Randomly select a cultural background
    String culture = cultures[Math.mod(Math.abs(Crypto.getRandomInteger()), cultures.size())];
    
    // Get the first and last name lists for the selected culture
    List<String> cultureFirstNames = culturalFirstNames.get(culture);
    List<String> cultureLastNames = culturalLastNames.get(culture);
    
    // Randomly select first and last names from the same cultural background
    String firstName = cultureFirstNames[Math.mod(Math.abs(Crypto.getRandomInteger()), cultureFirstNames.size())];
    String lastName = cultureLastNames[Math.mod(Math.abs(Crypto.getRandomInteger()), cultureLastNames.size())];
    
    Contact speakerContact = new Contact(
        FirstName = firstName,
        LastName = lastName,
        Email = firstName.toLowerCase() + '.' + lastName.toLowerCase() + i + '@example.com'
    );
    speakerContactRecords.add(speakerContact);
}

// Insert the contact records
insert speakerContactRecords;








//Get all session records
List<Session__c> sessionRecords = [SELECT Id FROM Session__c];

//Query for all Contact records
List<Contact> contactRecords = [SELECT Id FROM Contact];


//Create Session_Speaker__c records to join speakers to sessions, assign speakers randomly, with about half having two speakers
List < Session_Speaker__c > sessionSpeakerRecords = new List < Session_Speaker__c > ();
for (Session__c session : sessionRecords) {
    Session_Speaker__c sessionSpeaker = new Session_Speaker__c(
        Session__c = session.Id,
        Speaker__c = contactRecords[Math.mod(Math.abs(Crypto.getRandomInteger()), contactRecords.size())].Id
    );
    sessionSpeakerRecords.add(sessionSpeaker);
    //Add another speaker record for about half of the sessions
    if (Math.mod(Math.abs(Crypto.getRandomInteger()), 2) == 0) {
        sessionSpeaker = new Session_Speaker__c(
            Session__c = session.Id,
            Speaker__c = contactRecords[Math.mod(Math.abs(Crypto.getRandomInteger()), contactRecords.size())].Id
        );
        sessionSpeakerRecords.add(sessionSpeaker);
    }
}

insert sessionSpeakerRecords;