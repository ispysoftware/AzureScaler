# AzureScaler
Azure function to detect and auto scale cosmos DB and signalr servers according to load (because Microsoft don't provide any way to do this currently on Azure Portal) - me save you dollar!

Create a local.settings.json file containing the following

    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "powershell",
        "ServicePrincipalClientId": "", //See: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal
        "ServicePrincipalTenantId": "",
        "ServicePrincipalKey": "",// This is the application secret you created for the service principal (under Client Secrets)
        "SubscriptionID":"", //Your Azure subscription ID
        "CosmosThroughputBuffer":200,    //How much to add to the detected usage level
        "SignalRScaleLimit": 0.9, //So if scale is 1000 and usage is 901 it will scale to 2000
        "ScaleEnabled": 1 //set to 0 to just output to the console the actions it would take
      }
    }
