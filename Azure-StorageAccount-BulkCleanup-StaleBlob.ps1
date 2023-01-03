[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $subscriptionId
)

#Region Connect to Azure and set storage context
#Login to Azure
try{
    Write-Host -ForegroundColor Cyan "Signing in to Azure Portal . . ."
    Connect-AzAccount | Out-Null
}catch{
    Write-Verbose -Verbose "Failure connecting to the Azure Portal."
    exit
}

#Grab customer's subscriptions
try{
    Write-Host -ForegroundColor Cyan "Grabbing customer's subscription using subscriptionId: $subscriptionId . . ."
    $subscription = Get-AzSubscription | Where-Object{$_.Id -eq $subscriptionId}
}catch{
    Write-Verbose -Verbose "Could not pull subscription for $subscriptionId . . ."
    exit
}

#Select proper subscription context
try{
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
}
catch{
    Write-Error "Couldnt select $($sub.Id)" -ErrorAction Stop
}

# Create a context object using Azure AD credentials
$AZStorageAccountName = "teststorageaccount"        ## Replace teststorageaccount with the actual storage account name
$ctx = New-AzStorageContext -StorageAccountName $AZStorageAccountName -UseConnectedAccount

#EndRegion Connect to Azure and set storage context

#Region Evaluate and Remove or Audit Blob Storage
$AZStorageContainers = Get-AzStorageContainer -context $ctx | select -ExpandProperty name

$RetentionPeriod = 90
$Retentiondate = ((Get-Date).Adddays(-($RetentionPeriod)))


foreach($container in $AZStorageContainers){
    write-host "cleaning up files in $container that are older than $retentionperiod days" -ForegroundColor Yellow
    $AZBlobItems = @()
    $AZBlobItems = Get-AzStorageBlob -container $container -Context $ctx | where {[datetime]::ParseExact((($_.name).split("_","3")[2]).split("-","2")[0],'yyyy_MM_dd',$null) -lt $Retentiondate} | Remove-AzStorageBlob -Confirm:$false

}

#EndRegion Evaluate and Remove or Audit Blob Storage
