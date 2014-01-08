
# originally posted at https://github.com/JorritSalverda/msbuild-by-convention/
# based on https://www.windowsazure.com/en-us/develop/net/common-tasks/continuous-delivery/

Param(

	$serviceName = "",
	$storageAccountName = "",
	$packageLocation = "",
	$cloudConfigLocation = "",
	$deploymentLabel = "ContinuousDeploy to $servicename",
	$timeStampFormat = "s",

	$swapAfterDeploy = "True",
	$deleteStagingAfterSwap = "True",
	$enableDeploymentUpgrade = "True",

	$selectedsubscription = "default",

	$certificateFilename = "",
	$certificatePassword = "",
	$subscriptionid = ""

)

function Swap()
{
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot "Staging" -ErrorVariable a -ErrorAction silentlycontinue 
    if ($a[0] -ne $null)
    {
        Write-Output "$(Get-Date -f $timeStampFormat) - No staging deployment is detected. Not swapping. "
    }
    else
    {
      SpinUpDeployment("Staging")
      SwapDeployments
      SpinUpDeployment("Production")
    }		
}

function SpinUpDeployment($slot)
{
	$deployment = Get-AzureDeployment -slot $slot -serviceName $servicename
	$deploymentUrl = $deployment.Url
	$webclient = new-object net.WebClient

    Write-Output "$(Get-Date -f $timeStampFormat) - Spinning up deployment slot '$slot' at url '$deploymentUrl': In progress"

	Try
 	{
		[void]$webclient.downloadData($deploymentUrl)
 	}
	Catch [system.exception]
	{
	}

    Write-Output "$(Get-Date -f $timeStampFormat) - Spinning up deployment slot '$slot' at url '$deploymentUrl': Done"
}

function SwapDeployments()
{
    write-progress -id 5 -activity "Swapping slots" -status "In progress"
    Write-Output "$(Get-Date -f $timeStampFormat) - Swapping slots: In progress"

	$move = Move-AzureDeployment -ServiceName $serviceName
	
    write-progress -id 5 -activity "Swapping slots" -completed -status $move
    Write-Output "$(Get-Date -f $timeStampFormat) - Swapping slots: $move"	
}

#load the management certificate
$error.clear()
Write-Output "Loading certificate $certificateFilename for subscription $subscriptionid."
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.import($certificateFilename, $certificatePassword, "Exportable,PersistKeySet")

#load powershell commandlets
Get-ChildItem 'C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\*.psd1' | ForEach-Object {Import-Module $_}; 

Write-Output "Setting storage account $storageAccountName."
Set-AzureSubscription -CurrentStorageAccount $storageAccountName -SubscriptionName $selectedsubscription -SubscriptionId $subscriptionid -Certificate $cert
Set-AzureSubscription -DefaultSubscription $selectedsubscription

#set remaining environment variables for Azure cmdlets
$subscription = Get-AzureSubscription $selectedsubscription
$subscriptionname = $subscription.subscriptionname
$subscriptionid = $subscription.subscriptionid

#main driver - publish & write progress to activity log
Write-Output "$(Get-Date -f $timeStampFormat) - Azure Cloud Service deploy script started."
Write-Output "$(Get-Date -f $timeStampFormat) - Preparing deployment of $deploymentLabel for $subscriptionname with Subscription ID $subscriptionid."

Swap

$deployment = Get-AzureDeployment -slot "Production" -serviceName $servicename
$deploymentUrl = $deployment.Url

Write-Output "$(Get-Date -f $timeStampFormat) - Created Cloud Service with URL $deploymentUrl."
Write-Output "$(Get-Date -f $timeStampFormat) - Azure Cloud Service deploy script finished."
