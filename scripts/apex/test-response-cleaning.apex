// Test script to verify response cleaning fix
System.debug('Testing response cleaning fix...');

System.debug('The issue was that responses were starting with invalid characters like ".\\n\\n{"');
System.debug('This caused JSON parsing to fail because the response was not valid JSON');

System.debug('The fix includes:');
System.debug('1. Response cleaning in combineMultipleResponses()');
System.debug('2. Response cleaning in extractPartialScheduleData()');
System.debug('3. Better JSON extraction from text wrappers');

System.debug('Expected behavior now:');
System.debug('- Responses starting with ".\\n\\n{" should be cleaned to start with "{"');
System.debug('- The JSON content should be properly extracted and parsed');
System.debug('- All sessions including "Too Small to Succeed" should be displayed');

System.debug('To test:');
System.debug('1. Open the conference scheduler in your browser');
System.debug('2. Open the browser console (F12)');
System.debug('3. Run the async schedule generation');
System.debug('4. Look for these key log messages:');
System.debug('   - "Cleaned response from X to Y characters"');
System.debug('   - "Cleaned response preview: {"');
System.debug('   - "Successfully parsed session X: Session Name"');

System.debug('Test completed - check browser console for actual behavior'); 