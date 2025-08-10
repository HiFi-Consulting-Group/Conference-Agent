List < Session_Slot__c > sessionSlots = [SELECT Id FROM Session_Slot__c];
delete sessionSlots;
