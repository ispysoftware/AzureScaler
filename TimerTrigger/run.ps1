# Input bindings
param($Timer)

# Authenticate the service principle
$clientId = $env:ServicePrincipalClientId
$key = $env:ServicePrincipalKey
$securePassword = ConvertTo-SecureString $key -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($clientId, $securePassword)
$tenantId = $env:ServicePrincipalTenantId

Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $tenantId


#SignalR Scaling
# Get information about the current resource state
function CheckSigRService{
    param( $ID )

    $connectionsPerUnit = 1000          # Number of concurent connections you can have per unit
    $unitCounts = 1,2,5,10,20,50,100    # Supported SignalR Unit Counts
    $scaleThreshold = [double]$env:SignalRScaleLimit              # Percentage threshold at which to scale 
    $signalRSampleMinutes = [int]$env:SignalRSampleMinutes

    $signalRResource = Get-AzResource -ResourceId $ID -Verbose
    $currentUnitCount = [int]$signalRResource.Sku.Capacity
    Write-Host "Checking " $ID
    # Only scale if we are on the Standard_S1 plan
    if ($signalRResource.Sku.Name -eq "Standard_S1") {

        # Get metrics for the last n minutes (to allow scale operations to complete and clients to reconnect)
        $timegrain = '00:'+$signalRSampleMinutes+':00'
        if ($signalRSampleMinutes -lt 10) {
            $timegrain = '00:0'+$signalRSampleMinutes+':00'
        }

        $connectionCountMetric = Get-AzMetric -ResourceId $ID -MetricName "ConnectionCount" -TimeGrain $timegrain -StartTime (Get-Date).AddMinutes(0-$signalRSampleMinutes) -AggregationType Maximum -Verbose
        $maxConnectionCount = $connectionCountMetric.Timeseries.Data[0].Maximum

        if ($env:WebSiteNotifyURL -ne "")  {
            #update url with connection count
            $url = $env:WebSiteNotifyURL
            $headers = @{'Content-Type' = 'application/x-www-form-urlencoded';}
            $body = @{
                AuthKey = $env:WebSiteAuthKey
                Server = $ID
                Count = $maxConnectionCount
            }
         
            Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body
        }

        # Calculate the target unit count
        $targetUnitCount = 1
        foreach ($unitCount in $unitCounts) {
            $unitCountConnections = $unitCount * $connectionsPerUnit
            $unitCountConnectionsThreshold = $unitCountConnections * $scaleThreshold
            if ($unitCountConnectionsThreshold -gt $maxConnectionCount -or $unitCount -eq $unitCounts[$unitCounts.Count - 1]) {
                $targetUnitCount = $unitCount
                Break
            }
        }
        if ($targetUnitCount -gt $env:SignalRScaleMax)  {
            $targetUnitCount = $env:SignalRScaleMax
        }
        if ($targetUnitCount -lt $env:SignalRScaleMin)  {
            $targetUnitCount = $env:SignalRScaleMin
        }

        # See if we need to change the unit count
        if ($targetUnitCount -ne $currentUnitCount) {
            $scale = [int]$env:SignalRScaleDownEnabled -or  $targetUnitCount -gt $currentUnitCount
            if ($scale) {
                Write-Host "Scaling resource to unit count: " $targetUnitCount
                if ([int]$env:SignalRScaleEnabled)  {
                    # Change the resource unit count
                    $signalRResource.Sku.Capacity = $targetUnitCount
                    $signalRResource | Set-AzResource -Force
                    Write-Host "Done!"
                }
                else 
                {
                    Write-Host "Scaling action is disabled"
                }
            }
            else {
                Write-Host "Scaling action skipped"
            }
        } else {

            Write-Host "Not scaling as resource is already at the optimum unit count: " $currentUnitCount

        }

    } else {

        Write-Host "Can't scale as resource is not on a scalable plan: " $signalRResource.Sku.Name

    }
}

function New-AzureRmAuthToken
{
    [CmdletBinding()]
    Param
    (
    [System.String]
    $AadClientAppId,
    [System.String]
    $AadClientAppSecret,
    [System.String]
    $AadTenantId
    )
    Process
    { 
        # auth URIs 
        $aadUri = 'https://login.microsoftonline.com/{0}/oauth2/token' 
        $resource = 'https://management.core.windows.net'
        # load the web assembly and encode parameters 
        $null = [Reflection.Assembly]::LoadWithPartialName('System.Web')
        $encodedClientAppSecret = [System.Web.HttpUtility]::UrlEncode($AadClientAppSecret)
        $encodedResource = [System.Web.HttpUtility]::UrlEncode($Resource)
        # construct and send the request
        $tenantAuthUri = $aadUri -f $AadTenantId
        $headers = @{'Content-Type' = 'application/x-www-form-urlencoded';}
        $bodyParams = @("grant_type=client_credentials","client_id=$AadClientAppId","client_secret=$encodedClientAppSecret","resource=$encodedResource")
        $body = [System.String]::Join("&", $bodyParams)
        Invoke-RestMethod -Uri $tenantAuthUri -Method POST -Headers $headers -Body $body
    }
}

function CheckCosmosUsage
{
    [CmdletBinding()]
    Param
    (
        [System.String]
        $AuthToken,
        [System.String]
        $CosmosAccountName,
        [System.String]
        $CosmosDatabaseName,
        [System.String]
        $CosmosResourceGroup,
        [System.String]
        $CosmosDatabaseResourceID,
        [Int]
        $CosmosThroughputBuffer,
        [Int]
        $CosmosSampleMinutes
    )
    Process
    {
        Write-Host "Checking Cosmos DB " $CosmosDatabaseName
        $databaseResourceName  = $CosmosAccountName + "/sql/" + $CosmosDatabaseName + "/throughput"
        $res = Get-AzResource -ResourceType "Microsoft.DocumentDb/databaseAccounts/apis/databases/settings" `
            -ApiVersion $env:CosmosAPIVersion -ResourceGroupName $CosmosResourceGroup `
            -Name $databaseResourceName | Select-Object -expand Properties
        $throughput = [int] $res.throughput
        Write-Host "Current Throughput: "$throughput
        
        $startdate = (Get-Date).AddMinutes(0-$CosmosSampleMinutes).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.0000000Z")
        $enddate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.0000000Z")

        $query = "(name.value eq 'Max RUs Per Second') and timeGrain eq duration'PT1M' and startTime eq $startdate and endTime eq $enddate"
        Write-Host $query
        $encodequery = [uri]::EscapeDataString($query) 

        $url = 'https://management.azure.com/subscriptions/'+$env:SubscriptionID+'/resourceGroups/'+$CosmosResourceGroup+'/providers/Microsoft.DocumentDb/databaseAccounts/'+$CosmosAccountName+'/databases/'+$CosmosDatabaseResourceID+'/metrics?api-version='+$env:CosmosAPIVersion+'&$filter=' + $encodequery
        $headers = @{
            'Host' = 'management.azure.com'
            'Content-Type' = 'application/json';     
            'Authorization' = "Bearer $AuthToken";
        }
         
        $CosmosUsage = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
        
        $max = 0
        foreach ($i in $CosmosUsage.value)
        {
            foreach ($j in $i.metricValues)
            {
                if ($j.maximum -gt $max) {
                    $max = $j.maximum
                }
            }
        }
        if ($max -gt 0)   { #otherwise prob an error getting it
            Write-Host "Max Usage: " $max
            $buffer = $CosmosThroughputBuffer
            $newmax = [math]::Ceiling(($max+$buffer)/100)*100
            if ($newmax -lt [int]$env:CosmosMin) {
                $newmax = [int]$env:CosmosMin
            }
            if ($newmax -gt [int]$env:CosmosMax) {
                $newmax = [int]$env:CosmosMax
            }
            Write-Host "New Max: " $newmax

            if ($newmax -ne $throughput) {
                Write-Host "Setting new Max: " $newmax
                if ([int]$env:CosmosScaleEnabled)  {
                
                    $properties = @{"resource"=@{"throughput"=$newmax}}
                    Set-AzResource -ResourceType "Microsoft.DocumentDb/databaseAccounts/apis/databases/settings" `
                        -ApiVersion $env:CosmosAPIVersion -ResourceGroupName $CosmosResourceGroup `
                        -Name $databaseResourceName -PropertyObject $properties
			-Force
                    Write-Host "Done!"
                }
                else 
                {
                    Write-Host "Scaling action is disabled"
                }
            }
        }
        else {
            Write-Host "Max was zero - update skipped "
        }
    }
}

function ScaleCosmosDatabases {
    $accs = Get-AzResource -ResourceType Microsoft.DocumentDb/databaseAccounts
    foreach($acc in $accs)  {
        $accName = $acc.Name+'/sql/'
        $dbs = Get-AzResource -ResourceType Microsoft.DocumentDb/databaseAccounts/apis/databases -ApiVersion $env:CosmosAPIVersion -ResourceGroupName $acc.ResourceGroupName -Name $accName | Select-Object -expand Properties
        foreach($db in $dbs){
            CheckCosmosUsage -AuthToken $authToken -CosmosAccountName $acc.Name -CosmosDatabaseName $db.id -CosmosResourceGroup $acc.ResourceGroupName -CosmosDatabaseResourceID $db._rid -CosmosThroughputBuffer $env:CosmosThroughputBuffer -CosmosSampleMinutes $env:CosmosSampleMinutes
        }
    }
}

function ScaleSignalRServers {
    $url = 'https://management.azure.com/subscriptions/'+$env:SubscriptionID+'/providers/Microsoft.SignalRService/SignalR?api-version='+$env:SignalRAPIVersion
    $headers = @{
        'Host' = 'management.azure.com'
        'Content-Type' = 'application/json';     
        'Authorization' = "Bearer $authToken";
    }
     
    $ServerList = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
    foreach ($i in $ServerList.value)
    {
        if ($i.sku.name -eq "Standard_S1") {
            CheckSigRService -ID $i.id
        }
    }
}

$authResult = New-AzureRmAuthToken -AadClientAppId $env:ServicePrincipalClientId -AadClientAppSecret $env:ServicePrincipalKey -AadTenantId $env:ServicePrincipalTenantId
$authToken = $authResult.access_token

ScaleCosmosDatabases
ScaleSignalRServers
