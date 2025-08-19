// Test script to understand how Time field values are being converted to datetime objects
// This will help us understand why 14:00:00.000Z becomes 21:00:00

System.debug('=== Testing Time Field Conversion ===');

// Create a test date and time
Date testDate = Date.newInstance(2025, 9, 1);
Time testTime = Time.newInstance(14, 0, 0, 0); // 2:00 PM

System.debug('Test Date: ' + testDate);
System.debug('Test Time: ' + testTime);

// Create datetime objects
Datetime testDatetime = Datetime.newInstance(testDate, testTime);
System.debug('Datetime.newInstance(date, time): ' + testDatetime);

// Let's also test with the actual session slot time from the logs
// The session slot shows 14:00:00.000Z but becomes 21:00:00
Time slotTime = Time.newInstance(14, 0, 0, 0);
Datetime slotDatetime = Datetime.newInstance(testDate, slotTime);
System.debug('Slot time conversion: ' + slotTime + ' -> ' + slotDatetime);

// Check if there's a timezone offset issue
System.debug('Current user timezone: ' + UserInfo.getTimeZone());
System.debug('Current user timezone offset: ' + UserInfo.getTimeZone().getOffset(testDatetime));

// Test with different times to see the pattern
for (Integer hour = 7; hour <= 17; hour++) {
    Time businessTime = Time.newInstance(hour, 0, 0, 0);
    Datetime businessDatetime = Datetime.newInstance(testDate, businessTime);
    System.debug('Hour ' + hour + ':00 -> ' + businessDatetime);
}

System.debug('=== Test Complete ==='); 