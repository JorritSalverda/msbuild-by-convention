
# originally posted at https://github.com/JorritSalverda/msbuild-by-convention/
# based on https://www.windowsazure.com/en-us/develop/net/common-tasks/continuous-delivery/

Param(

	$serviceName = "",
	$storageAccountName = "",
	$timeStampFormat = "g",

	$hostedServiceSlot = "Staging",

	$selectedsubscription = "default",

	$certificateFilename = "",
	$certificatePassword = "",
	$subscriptionid = ""

)

function DeleteDeployment($slot)
{
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot "Staging" -ErrorVariable a -ErrorAction silentlycontinue 
    if ($a[0] -ne $null)
    {
        Write-Output "$(Get-Date -f $timeStampFormat) - No deployment is detected. Skipping delete."
    }
	
    #check for existing deployment and then delete
    if ($deployment.Name -ne $null)
    {
		write-progress -id 2 -activity "Deleting Deployment" -Status "In progress"
		Write-Output "$(Get-Date -f $timeStampFormat) - Deleting Deployment: In progress"

		#WARNING - always deletes with force
		$removeDeployment = Remove-AzureDeployment -Slot $slot -ServiceName $serviceName -Force

		write-progress -id 2 -activity "Deleting Deployment: Complete" -completed -Status $removeDeployment
		Write-Output "$(Get-Date -f $timeStampFormat) - Deleting Deployment: Complete"
	}
}

#load the management certificate
$error.clear()
Write-Output "Loading certificate $certificateFilename for subscription $subscriptionid."
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.import($certificateFilename, $certificatePassword, "Exportable,PersistKeySet")

#load powershell commandlets
Get-ChildItem 'C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\*.psd1' | ForEach-Object {Import-Module $_}; 

Set-AzureSubscription -SubscriptionName $selectedsubscription -SubscriptionId $subscriptionid -Certificate $cert
Set-AzureSubscription -DefaultSubscription $selectedsubscription

#set remaining environment variables for Azure cmdlets
$subscription = Get-AzureSubscription $selectedsubscription
$subscriptionname = $subscription.subscriptionname
$subscriptionid = $subscription.subscriptionid

#main driver - publish & write progress to activity log
Write-Output "$(Get-Date -f $timeStampFormat) - Azure Cloud Service delete script started."

DeleteDeployment($hostedServiceSlot)

Write-Output "$(Get-Date -f $timeStampFormat) - Azure Cloud Service delete script finished."
