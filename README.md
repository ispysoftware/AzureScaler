# AzureScaler
Azure function to detect and auto scale cosmos DB and signalr servers according to load on an Azure subscription. The cosmos DB scaler will adjust the max throughput of a database based on the maximum RU seen over the past 5 minutes.


Create a local.settings.json file containing the following

<ul>
<li>ServicePrincipalClientId - See: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal</li>
<li>ServicePrincipalKey - This is the application secret you created for the service principal (under Client Secrets)</li>
<li>SubscriptionID - Your Azure subscription ID</li>
<li>CosmosThroughputBuffer - How much to add to the detected usage level</li>
<li>SignalRScaleLimit - 0.9 = If scale is 1000 and usage is 901 it will scale to 2000</li>
<li>ScaleEnabled - Set to 0 to just output to the console the actions it would take</li>
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
        "CosmosThroughputBuffer":200,
        "CosmosMin":400,
        "CosmosMax":10000,
        "SignalRScaleLimit": 0.9, 
        "ScaleEnabled": 1,
        "CosmosAPIVersion": "2015-04-08",
        "SignalRAPIVersion": "2018-10-01"
      }
    }
