# Migration Testing

# 1. Distributed Setup Deployment
### 1.1. Node setup

Prior to the migration of the APIM 3.1.0 version from APIM 2.6.0, it is required to set up a distributed deployment environment (Ex: Using AWS EC2 instances.)

The following are the instance types used for each profile in the cloud deployment. 
| Instance | Instance Type |
| ------ | ------ |
| RDS |db.m5.2xlarge|
| Key Manager | c5.xlarge |
| Gateway | c5.xlarge |
| Publisher | c5.xlarge |
| Traffic Manager | c5.xlarge |
| NGINX | c5.xlarge |

Using the above instances, the user has to deploy a distributed system according to the following deployment architecture. 
https://github.com/Chamindu36/Migration-testing/blob/master/DistributedSetup.jpg

In order to set up the above-distributed environment, all the nodes should be installed with Java 8 , and the latest APIM 3.1.0 WUM pack needed to be installed in all those nodes except the Load balancer node (NGINX node). Then according to the type of the node WSO2 APIM gateways need to be configured. When configuring the nodes it is optional to enable clustering configurations for Gateway and Key manager nodes.

Eg: If a single node is going to configure as Key manager of this setup that node’s wso2 API Manger’s deployment has to be changed as it is supposed to provide services as a Key Manager.
The configurations based on the service that the node is going to provide in a distributed system can be configured by following the documentation [1]. 
[1].https://apim.docs.wso2.com/en/3.1.0/install-and-setup/setup/distributed-deployment/

The configured deployment. toml files are provided in this Repo.

### 1.2. NGINX load balancer setup

After these configurations which are configured in WSO2 API manager packs in different nodes, the NGINX load balancer needs to be configured as follows. These configurations need to be added in */etc/nginx/conf.d/* path of Nginx node.
### gateway_upstream.conf
```sh
upstream gateway_https {
        least_conn;
        server x.x.x.x:8243;
        server y.y.y.y:8243;
        server z.z.z.z:8243;
}
```
### keymanager_upstream.conf
```sh
upstream keymanager {
#        zone keymanager 64k;

        server a.a.a.a:9443;
        server b.b.b.b:9443;
}
```
### pubstore_upstream.conf 
```sh
upstream pubstore {

        zone pubstore 64k;

        server t.t.t.t:9443;

}
```
### trafficmanager_upstream.conf
```sh
upstream trafficmanager {
        zone trafficmanager 64k;

        server k.k.k.k:9443;
}

```
### 1.3. SQL database instance setup
Since this distributed setup is using MySQL as its database server, that node needs to be configured by following the instructions given in the WSO2 documentation attached here [2].
[2].https://apim.docs.wso2.com/en/3.1.0/install-and-setup/setup/setting-up-databases/changing-default-databases/changing-to-mysql/

# 2. Load a sufficient amount of data  to set up using an automated client script

Before performing load tests on this distributed setup sufficient amount of data needed to be loaded into this setup. Therefore prior to the performance tests an automated data client needs to be executed on these nodes in order to load this environment with tenants, APIs, Applications, subscriptions, and access tokens for API invocation with different grant types. There is an automated sample client to load this environment with a sufficient amount of data is attached here.

##### Setup Environment before loading data to that environment 
* Create store server instance based on configuration given at automation.xml
* Create a publisher server instance based on configuration given at automation.xml       
* Create a gateway server instance based on configuration given at  automation.xml
* Then add tenants to these environments

##### Then populate data until the setup is filled with sufficient data load
* Add and activate a tenant
* Add publisher user for that tenant
* Create the required no of APIs per tenant as publisher user of that tenant and publish those created APIs.
* Add a Devportal user for a created tenant.
* Create the required amount of subscribers for each tenant with one application and subscription per each subscriber.
* Generate access tokens for each subscriber with desired grant types. 

    Initially, we have added using the above-attached client script.
    * 100 tenants 
    * 10 APIs for each tenant 
    * 10 subscribers for each tenant with one application with two grant types (client-credentials and password) who subscribed to one API each.
    * 100000 tokens with client credentials and password grant types.
    
To get a summary of the count of access tokens with different grant types created in the Database instance following SQL query can be used.

```sh
SELECT GRANT_TYPE, COUNT(GRANT_TYPE)
FROM  IDN_OAUTH2_ACCESS_TOKEN 
GROUP BY GRANT_TYPE;
```

****When adding these tenants and other data it required a large amount of read-write operation and a large number of database connections. Therefore make sure to add these data as chunks instead of adding all the data load at once to avoid occurring  SQL lock timeouts during the data loading process.**

After this initial data load up, we have run this client script several times to create a data load which is similar to the data load in the API Manager Cloud setup. After the final data loading is completed, the environment contains about 3000 tenants with 200 activated tenants and about 50,000 tokens in different Grant types.

# 3. Performing load tests using Jmeter scripts.

### 3.1. Extracting required data from the database


Prior to performing these tests with Jmeters, there is some data needed to be extracted from the Database which is required to create requests in order to perform load tests. Using SQL queries the user can extract these data from the database. The steps mentioned here need to be followed in order to extract the data from the database and preprocess them before feeding to Jmeter scripts.

###### Steps to be followed 

* Log in to the database instance and select the database which APIM is using.
* Create an SQL query required to extract data from the database.
    Eg:  Let’s assume the user needs to extract details from the database to test Client-credentials grant type-token requests using Jmeter scripts. This is the SQL query to extract the required data from the database.

    ```sh
    SELECT  CONCAT (A.CONTEXT, '/') as CONTEXT , T.ACCESS_TOKEN ,T.REFRESH_TOKEN,C.CONSUMER_KEY,C.CONSUMER_SECRET
    
    FROM AM_API AS A, AM_SUBSCRIPTION AS S, AM_APPLICATION  AS AP, IDN_OAUTH2_ACCESS_TOKEN AS T,IDN_OAUTH_CONSUMER_APPS AS C, AM_APPLICATION_KEY_MAPPING  AS AM
    
    WHERE A.API_ID = S.API_ID  AND S.APPLICATION_ID =AP.APPLICATION_ID AND AP.APPLICATION_ID =AM.APPLICATION_ID  AND AM.CONSUMER_KEY =C.CONSUMER_KEY AND C.ID =T.CONSUMER_KEY_ID;
    ```
* Then the user has to extract the result of that query into a  .csv file.
* The created .csv file has data separated from spaces and those spaces need to be replaced with “,” which is a requirement when extracting data into Jmeter scripts.
* Then based on the tenant IDs data populated in the .csv file needs to be separated and moved into separate .csv files. (If each tenant has the same amount of data per tenant user can use a shell script to perform this task. Otherwise, this task has to be performed manually)

### 3.2. Prepare Jmeter scripts

When the data extraction and preprocessing are completed the user can start implementing Jmeter scripts for any scenario that needs to be tested with this environment. Whenever a user prepares a Jmeter script for distributed setup running on cloud instances it is safe to follow these steps to verify that Jmeter scripts are implemented without any flows.
###### Steps to be followed 

* Implement the scenario needed to be tested in a distributed setup in a script, that runs in a local all in one setup and verify the validity of the Jmeter script using the local setup.
* Then create the same scenario in a Jmeter script that runs on a distributed setup without considering time durations and looping conditions. (Just for one instance)
* Then apply all the time durations and looping conditions and add multiple thread groups to test the above scenario with multiple tenants.
* Run JMeter scripts for a specified time duration with specified loads of requests.

### 3.3. Observer Outcomes and Results

Once the JMeter test scripts are running for a specific time using AWS analytics, the user can monitor the CPU Utilization and Database connections of RDS instances and CPU utilization of Key manager nodes and Traffic manager nodes in order to get the measurements on performed load testings.
During the period of time, these Jmeter scripts are running the user can tail and see wso2carbon.log in gateway nodes and Key manager nodes to check whether these testings are causing any errors or failures which are not expected.
By performing these two monitoring tasks for different scenarios and different combinations (such as load testings with different grant type access tokens used to invoke APIs ), the tester can derive a conclusion about the behavior of the API Manager 3.1.0 product.