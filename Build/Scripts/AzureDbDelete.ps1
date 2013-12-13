
# originally posted at https://github.com/JorritSalverda/msbuild-by-convention/
# based on https://www.windowsazure.com/en-us/develop/net/common-tasks/continuous-delivery/

Param(

	$serverName = "",
	$databaseName = "",
	
	$username = "",
	$password = "",
	
	$timeStampFormat = "g",

	$selectedsubscription = "default",

	$certificateFilename = "",
	$certificatePassword = "",
	$subscriptionid = ""

)

function DeleteDatabase()
{
  Remove-AzureSqlDatabase -ServerName $serverName -DatabaseName $databaseName -Force
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
Write-Output "$(Get-Date -f $timeStampFormat) - Azure database delete script started."

DeleteDatabase

Write-Output "$(Get-Date -f $timeStampFormat) - Azure database delete script finished."
