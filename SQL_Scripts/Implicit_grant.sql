USE dbApiMgtProd310;
SELECT  CONCAT (A.CONTEXT, '/') as CONTEXT,SUBSTRING_INDEX(SB.USER_ID,'@',-1), C.CONSUMER_KEY,C.CONSUMER_SECRET 
FROM AM_API AS A, AM_SUBSCRIPTION AS S, AM_APPLICATION  AS AP, IDN_OAUTH2_ACCESS_TOKEN AS T,IDN_OAUTH_CONSUMER_APPS AS C, AM_APPLICATION_KEY_MAPPING  AS AM, AM_SUBSCRIBER AS SB 
WHERE A.API_ID = S.API_ID  AND S.APPLICATION_ID =AP.APPLICATION_ID AND AP.APPLICATION_ID =AM.APPLICATION_ID  AND AM.CONSUMER_KEY =C.CONSUMER_KEY AND C.ID =T.CONSUMER_KEY_ID AND AP.SUBSCRIBER_ID=SB.SUBSCRIBER_ID AND AP.NAME="NEW_APPLICATION_3";