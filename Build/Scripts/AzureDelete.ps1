
# originally posted at https://github.com/JorritSalverda/msbuild-by-convention/

$error.clear()
$subscriptionId = $args[0]

$certificateFilename = $args[1]
$certificatePassword = $args[2]
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.import($certificateFilename, $certificatePassword, "Exportable,PersistKeySet")

$servicename = $args[3]
$slot = $args[4]
 
if ((Get-PSSnapin | ?{$_.Name -eq "WAPPSCmdlets"}) -eq $null)
{
	Add-PSSnapin WAPPSCmdlets
}

Write-Output "Deleting $servicename, slot $slot."

# get 'staging|production' deployment status
$getHostedServiceStaging = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot $slot 
 
# remove 'staging|production' if exists
if ($getHostedServiceStaging.Status -ne $null)
{
	Write-Output "Instances exists; we're taking them down."

	# set to suspended first
    $getHostedServiceStaging |
      Set-DeploymentStatus 'Suspended' |
      Get-OperationStatus -WaitToComplete
	  
	# now remove it
    $getHostedServiceStaging |
      Remove-Deployment |
      Get-OperationStatus -WaitToComplete
	  
	Write-Output "Instances are removed."
}
 
if ($error) { exit 888 }