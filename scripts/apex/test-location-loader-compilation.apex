// Test script to verify LocationLoader compilation after timezone fix
// This script tests that the LocationLoader class compiles without errors

System.debug('=== Testing LocationLoader Compilation ===');

try {
    // Test 1: Verify we can create instances of the LocationLoader classes
    System.debug('Testing LocationLoader class compilation...');
    
    // Test LocationAvailability constructor
    LocationLoader.LocationAvailability testAvailability = new LocationLoader.LocationAvailability();
    System.debug('LocationAvailability default constructor works');
    
    // Test LocationAvailability constructor with parameters
    LocationLoader.LocationAvailability testAvailability2 = new LocationLoader.LocationAvailability(
        '001000000000000', // Dummy location ID
        'Test Room',
        '001000000000001', // Dummy event ID
        50,
        'Medium',
        Date.today(),
        System.now(),
        System.now().addHours(1)
    );
    System.debug('LocationAvailability parameterized constructor works');
    
    // Test LocationWithAvailability constructor
    LocationLoader.LocationWithAvailability testLocation = new LocationLoader.LocationWithAvailability();
    System.debug('LocationWithAvailability default constructor works');
    
    // Test LocationWithAvailability constructor with parameters
    LocationLoader.LocationWithAvailability testLocation2 = new LocationLoader.LocationWithAvailability(
        '001000000000000', // Dummy location ID
        'Test Room',
        '001000000000001', // Dummy event ID
        50,
        'Medium'
    );
    System.debug('LocationWithAvailability parameterized constructor works');
    
    // Test 2: Verify the method signature is correct
    System.debug('Testing loadLocationAvailability method signature...');
    
    // This should compile without errors (method exists and is static)
    List<String> result = LocationLoader.loadLocationAvailability(new List<Id>());
    System.debug('loadLocationAvailability method signature is correct');
    
    System.debug('=== LocationLoader Compilation Test Completed Successfully ===');
    System.debug('All timezone-related changes compile without errors.');
    
} catch (Exception e) {
    System.debug('Error during LocationLoader compilation test: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
} 