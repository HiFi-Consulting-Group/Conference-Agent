// Test script to debug multi-part response handling
System.debug('Testing multi-part response debugging...');

// This script helps understand what's happening with the async session
// Run this after initiating an async session to see the current state

System.debug('To debug multi-part responses:');
System.debug('1. Open the conference scheduler in your browser');
System.debug('2. Open the browser console (F12)');
System.debug('3. Run the async schedule generation');
System.debug('4. Look for these key log messages:');
System.debug('   - "Response indicates more parts are coming, waiting for completion..."');
System.debug('   - "=== waitForAllParts called ==="');
System.debug('   - "Checking for additional parts:"');
System.debug('   - "Current response length:" vs "First part length:"');
System.debug('5. Check if the response contains indicators like:');
System.debug('   - "Part 1"');
System.debug('   - "Part 2 will follow"');
System.debug('   - "more parts"');

System.debug('Expected behavior:');
System.debug('- System should detect "Part 1" and "Part 2 will follow"');
System.debug('- Should continue polling for additional content');
System.debug('- Should combine all parts into a single schedule');
System.debug('- Should display all sessions including "Too Small to Succeed"');

System.debug('If this is not working:');
System.debug('- Check if the AI agent is actually sending multiple parts');
System.debug('- Check if the async session is being updated with more content');
System.debug('- Check if the response length is increasing over time');

System.debug('Test completed - check browser console for actual behavior'); 