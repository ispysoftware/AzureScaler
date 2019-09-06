# TimerTrigger - PowerShell

The `TimerTrigger` makes it incredibly easy to have your functions executed on a schedule. This sample demonstrates a simple use case of calling your function every 5 minutes.

## How it works

For a `TimerTrigger` to work, you provide a schedule in the form of a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression)(See the link for full details). A cron expression is a string with 6 separate expressions which represent a given schedule via patterns. The pattern we use to represent every 5 minutes is `0 */5 * * * *`. This, in plain text, means: "When seconds is equal to 0, minutes is divisible by 5, for any hour, day of the month, month, day of the week, or year".

## Learn more


Create a local.settings.json file containing the following

{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "powershell",
    "ServicePrincipalClientId": "", //See: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal
    "ServicePrincipalTenantId": "",
    "ServicePrincipalKey": "",// This is the application ID you created for the service principal
    "SubscriptionID":"", //Your Azure subscription ID
    "CosmosThroughputBuffer":200,    //How much to add to the detected usage level
    "SignalRScaleLimit": 0.9, //So if scale is 1000 and usage is 901 it will scale to 2000
    "ScaleEnabled": 1 //set to 0 to just output to the console the actions it would take
  }
}
