List < ScheduleAgentLocationController.SessionInput > sessions = new List < ScheduleAgentLocationController.SessionInput > ();

List<ScheduleAgentLocationController.LocationArray> locations = ScheduleAgentLocationController.getLocations(sessions);
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


//Select all Contact records created today by me
List<Contact> myContacts = [SELECT Id, FirstName, LastName FROM Contact WHERE CreatedById = :UserInfo.getUserId() AND CreatedDate = TODAY];

//Loop through and find any contact records where there is already a contact with the exact same FirstName and LastName. we will delete them.
Set<String> contactNames = new Set<String>();
List<Contact> contactsToDelete = new List<Contact>();
for (Contact contact : myContacts) {
    if (contactNames.contains(contact.FirstName + ' ' + contact.LastName)) {
        contactsToDelete.add(contact);
    } else {
        contactNames.add(contact.FirstName + ' ' + contact.LastName);
    }
}

delete contactsToDelete;


//Let's create some sample sessions. First, query for existing Session__c records up to 150 records
List<Session__c> existingSessions = [SELECT Id, Title__c  FROM Session__c LIMIT 100];

//Query for all the Contact records created today that still exist
List<Contact> existingContacts = [SELECT Id, FirstName, LastName FROM Contact WHERE CreatedById = :UserInfo.getUserId() AND CreatedDate = TODAY];
//Create a map with the index as the key and the contact as the value
Map<Integer, Contact> contactMap = new Map<Integer, Contact>();
for (Integer i = 0; i < existingContacts.size(); i++) {
    contactMap.put(i, existingContacts[i]);
}

//Get the picklist option values for Format__c
List<Schema.PicklistEntry> formatPicklistEntries = Session__c.Format__c.getDescribe().getPicklistValues();

//Get the picklist option values for Focus__c
List<Schema.PicklistEntry> focusPicklistEntries = Session__c.Focus__c.getDescribe().getPicklistValues();

//Create a map with the index as the key and the picklist entry as the value
Map<Integer, String> formatMap = new Map<Integer, String>();
for (Integer i = 0; i < formatPicklistEntries.size(); i++) {
    formatMap.put(i, formatPicklistEntries[i].getValue());
}

//Create a map with the index as the key and the picklist entry as the value
Map<Integer, String> focusMap = new Map<Integer, String>();
for (Integer i = 0; i < focusPicklistEntries.size(); i++) {
    focusMap.put(i, focusPicklistEntries[i].getValue());
}

//Now, let's create 150 new Session__c records
//Pick a Focus and Format at random
List<Session__c> newSessions = new List<Session__c>();
for (Integer i = 0; i < existingSessions.size(); i++) {
    //Create a list of valid room size values
    List<String> roomSizes = new List<String>{'Small (under 50)', 'Medium (50-150)', 'Large (151+)'};
    
    Session__c session = new Session__c(
        Title__c = existingSessions[i].Title__c,
        Event__c = 'a2DWJ00000EqmGb2AJ',
        Focus__c = focusMap.get(Math.mod(Math.abs(Crypto.getRandomInteger()), focusMap.size())),
        Format__c = formatMap.get(Math.mod(Math.abs(Crypto.getRandomInteger()), formatMap.size())),
        Requested_Room_Size__c = roomSizes[Math.mod(Math.abs(Crypto.getRandomInteger()), roomSizes.size())]
    );

    newSessions.add(session);
}

insert newSessions;

//Now let's randomly assign speakers(that were created today) to the sessions we created today. Most sessions should have one speaker, but some can have more than one. We do this by creating Session Speaker records to join the session to the speaker(s)

//Query for the sessions we just created today
List<Session__c> todaysSessions = [SELECT Id FROM Session__c WHERE CreatedById = :UserInfo.getUserId() AND CreatedDate = TODAY];

//Query for the speakers we created today
List<Contact> todaysSpeakers = [SELECT Id FROM Contact WHERE CreatedById = :UserInfo.getUserId() AND CreatedDate = TODAY];

//Create Session_Speaker__c records to join speakers to sessions
List<Session_Speaker__c> newSessionSpeakers = new List<Session_Speaker__c>();

for (Session__c session : todaysSessions) {
    //Assign at least one speaker to each session
    Session_Speaker__c sessionSpeaker = new Session_Speaker__c(
        Session__c = session.Id,
        Speaker__c = todaysSpeakers[Math.mod(Math.abs(Crypto.getRandomInteger()), todaysSpeakers.size())].Id
    );
    newSessionSpeakers.add(sessionSpeaker);
    
    //Add a second speaker for about 30% of sessions
    if (Math.mod(Math.abs(Crypto.getRandomInteger()), 10) < 3) {
        Session_Speaker__c secondSpeaker = new Session_Speaker__c(
            Session__c = session.Id,
            Speaker__c = todaysSpeakers[Math.mod(Math.abs(Crypto.getRandomInteger()), todaysSpeakers.size())].Id
        );
        newSessionSpeakers.add(secondSpeaker);
    }
    
    //Add a third speaker for about 10% of sessions
    if (Math.mod(Math.abs(Crypto.getRandomInteger()), 10) < 1) {
        Session_Speaker__c thirdSpeaker = new Session_Speaker__c(
            Session__c = session.Id,
            Speaker__c = todaysSpeakers[Math.mod(Math.abs(Crypto.getRandomInteger()), todaysSpeakers.size())].Id
        );
        newSessionSpeakers.add(thirdSpeaker);
    }
}

//Insert the session speaker records
insert newSessionSpeakers;

System.debug('Created ' + newSessionSpeakers.size() + ' Session_Speaker__c records');

