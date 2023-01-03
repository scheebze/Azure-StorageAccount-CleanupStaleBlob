[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $subscriptionId
)

#Feature Flags
$audit = $true
$DeleteStaleRecords =  $false

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

$exportdata = @()

foreach($container in $AZStorageContainers){
    $AZBlobItems = @()
    $AZBlobItems = Get-AzStorageBlob -container $container -Context $ctx 

    
    $a = 1
    $b = $AZBlobItems.count  
    #Begin loop
    foreach($item in $AZBlobItems){
        $blobname = @()
        $blobname = $item.Name

        Write-host "$container - Working on item $a of $b - $blobname"
        #Regex to cleanup blobname and just get date
        $datestring = @()
        $datestring = (($blobname.split("_","3"))[2]).split("-","2")[0]

        #convert string from file into valid date time formate
        $dateconverted = @()
        $dateconverted = [datetime]::ParseExact($datestring,'yyyy_MM_dd',$null)

        #Evaluate if file should be deleted
        $DeleteFile = @()
        if($dateconverted -lt $Retentiondate){
            $DeleteFile = $true
            write-host "$blobname is older than 90 days." -ForegroundColor DarkCyan
        }
        else{
            $DeleteFile = $false
            write-host "$blobname is younger than 90 days." -ForegroundColor DarkGreen
        }

        #Generate Audit Report if feature is enabled
        if($audit -eq $true){
            Write-host "Adding Data to Audit Report" -ForegroundColor Yellow
            #Add Data to row
            $Row = [PSCustomObject]@{
                container               = $container
                blobname                = $blobname
                DeleteFile				= $DeleteFile
            }
            #Add row to Export Data
            $exportdata += $row
        }

        #Delete file if feature is enabled    
        if($DeleteStaleRecords -eq $true -and $deletefile -eq $true){
            Write-host "Deleting $blobname" -ForegroundColor Yellow
            try{
                Get-AzStorageBlob -container $container -context $ctx -Blob $blobname | Remove-AzStorageBlob -confirm:$false 
                write-host "Deleted $blobname" -ForegroundColor Magenta
            }
            catch{
                $error[0].exception
            }
        }

        #Write to host if audit and delete is not enabled
        if($audit -eq $false -and $DeleteStaleRecords -eq $false){
            Write-Host "$blobname | $dateConverted | deletefile:$deletefile " -ForegroundColor DarkCyan
        }
        $a++
    }
}

#Export Data
if($audit -eq $true){
    Write-host "Exporting Data" -ForegroundColor Yellow
    $exportdata | Export-Csv -NoTypeInformation "C:\temp\deletecontent.csv "
}

#EndRegion Evaluate and Remove or Audit Blob Storage


## The below will also accomplish the same task if you pipe remove-azstorageblob instead of the select statement. 
## This is good for bulk jobs as it will run against many at a time instead of 1 blob at a time.

#Get-AzStorageBlob -container $container -Context $ctx | where {[datetime]::ParseExact((($_.name).split("_","3")[2]).split("-","2")[0],'yyyy_MM_dd',$null) -lt $Retentiondate} | select name
