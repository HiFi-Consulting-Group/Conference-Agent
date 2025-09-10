public with sharing class AgentforceHomepageController {
    @AuraEnabled(cacheable=true)
    public static String getAgentforceBannerUrl(Integer index) {
        String docName='agentforceHomepageBanner' + ((index>0)?index+'':'');
        return getBannerUrlFromName(docName);
    }

    private static String getBannerUrlFromName(String docName) {
        try {
           Document doc = [SELECT Id FROM Document where Name = :docName LIMIT 1];  
                    System.debug('file URL: ' + '/servlet/servlet.ImageServer?id=' + doc.Id + '&oid=' + UserInfo.getOrganizationId() );

          return '/servlet/servlet.ImageServer?id=' + doc.Id + '&oid=' + UserInfo.getOrganizationId();
       }  catch (Exception e) {
          // Handle exceptions and return null if the file is not found
         System.debug('Error retrieving file ID: ' + e.getMessage());
         return null;
        }
    }
}