# AzureScaler
Azure function to detect and auto scale cosmos DB and signalr servers according to load on an Azure subscription. The cosmos DB scaler will adjust the max throughput of a database based on the maximum RU seen over the past 5 minutes and the number of clients connected to signalr.


Create a local.settings.json file containing the following

<ul>
<li>ServicePrincipalClientId - See: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal</li>
<li>ServicePrincipalKey - This is the application secret you created for the service principal (under Client Secrets)</li>
<li>SubscriptionID - Your Azure subscription ID</li>

<li>SignalRScaleLimit - 0.9 = If scale is 1000 and usage is 901 it will scale to 2000</li>
<li>SignalRScaleDownEnabled - Set to 1 to enable scale down operations as well as up (scaling disconnects all connected clients (!))</li>
<li>SignalRScaleEnabled - Set to 0 to just output to the console the actions it would take</li>

<li>CosmosThroughputBuffer - How much to add to the detected usage level</li>
<li>CosmosScaleEnabled - Set to 0 to just output to the console the actions it would take</li>
<li>WebSiteNotifyURL - Used to sync signalr connection stats to your web server (can be blank)</li>
<li>WebSiteAuthKey - Used to authenticate signalr connection stats to your web server (anything you like)</li>

</ul>

    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "powershell",
        "ServicePrincipalClientId": "",
        "ServicePrincipalTenantId": "",
        "ServicePrincipalKey": "",
        "SubscriptionID":"",
        "SignalRScaleLimit": 0.9,
        "SignalRSampleMinutes": 30,
        "SignalRScaleMax": 50,
        "SignalRScaleMin": 1,
        "SignalRScaleDownEnabled": 0,
        "SignalRScaleEnabled": 0,
        "SignalRAPIVersion": "2018-10-01",

        "CosmosThroughputBuffer":200,    
        "CosmosSampleMinutes": 10,
        "CosmosMax":10000,    
        "CosmosMin":500,    
        "CosmosScaleEnabled": 0,
        "CosmosAPIVersion": "2015-04-08",

        "WebSiteAuthKey":"",
        "WebSiteNotifyURL": ""
      }
    }
