
# originally posted at https://github.com/JorritSalverda/msbuild-by-convention/

$error.clear()
$subscriptionId = $args[0]

$certificateFilename = $args[1]
$certificatePassword = $args[2]
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.import($certificateFilename, $certificatePassword, "Exportable,PersistKeySet")

$buildPath = $args[3]
$packagename = $args[4]
$serviceconfig = $args[5]
$servicename = $args[6]
$storageAccount = $args[7]
$storageAccountKey = $args[8]
$buildVersion = $args[9]
$swapToProductionAfterDeploy = $args[10]
$removeStagingAfterSwap = $args[11]
$disallowMultipleActiveInstances = $args[12]

$package = join-path $buildPath $packageName
$config = join-path $buildPath $serviceconfig
$a = Get-Date
$buildLabel = $buildVersion + " (" + $a.ToShortDateString() + "-" + $a.ToShortTimeString() + ")"
 
if ((Get-PSSnapin | ?{$_.Name -eq "WAPPSCmdlets"}) -eq $null)
{
	Add-PSSnapin WAPPSCmdlets
}

Write-Output "Deploying $packagename version $buildVersion to $servicename."

# get 'staging' deployment status
$getHostedServiceStaging = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Staging' 
 
# remove old 'staging' deploy if exists
if ($getHostedServiceStaging.Status -ne $null)
{
	Write-Output "Staging instances already exists; we're taking them down."

	# set to suspended first
    $getHostedServiceStaging |
      Set-DeploymentStatus 'Suspended' |
      Get-OperationStatus -WaitToComplete
	  
	# now remove it
    $getHostedServiceStaging |
      Remove-Deployment |
      Get-OperationStatus -WaitToComplete
	  
	Write-Output "Staging instances are removed."
}

Write-Output "Deploying new package."

# deploy the package to 'staging'
Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | 
    New-Deployment 'Staging' -package $package -configuration $config -label $buildLabel -serviceName $servicename -StorageServiceName $storageAccount |
    Get-OperationStatus -WaitToComplete

Write-Output "Done deploying new package."	
	
if ($disallowMultipleActiveInstances -ne "True")
{
	Write-Output "Spinning up staging instances."
		
	# spin the deployment up to 'running'
	Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Staging' |
		Set-DeploymentStatus 'Running' |
		Get-OperationStatus -WaitToComplete
	 
	# the completion of previous action doesn't necessarily mean it's really ready, so check the status until it is 'Ready' and the name until it matches the one we used for our deployment
	$ready = $False
	while(!$ready)
	{
		$d = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Staging' 
		$ready = ($d.RoleInstanceList[0].InstanceStatus -eq "Ready") -and ($d.Label -eq $buildLabel)
	} 

	Write-Output "Done spinning up staging instances."
	
	$d = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Staging' 
	$stagingurl = $d.Url
	
	Write-Output "Starting staging website at url $stagingurl"
	$webclient = new-object net.WebClient
	Try
	{
		[void]$webclient.downloadData($stagingurl)
	}
	Catch [system.exception]
	{
		$error.clear()
	}
}
else
{
	Write-Output "Keeping staging suspended, because only 1 active instance is allowed."
}
 
# if $swapToProductionAfterDeploy argument equals 'True' we want to deploy all the way to production, so we swap instances; for the real production environment we would probably do this by hand
if ($swapToProductionAfterDeploy -eq "True")
{
	if ($disallowMultipleActiveInstances -eq "True")
	{	
		# get 'production' deployment status 
		$getHostedServiceStaging = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Production' 
		 
		# suspend 'staging' deploy if exists, which only is the case if we had a former 'Production' instance
		if ($getHostedServiceStaging.Status -ne $null)
		{
			Write-Output "Suspending production first, so only 1 instance is active."
		
			# set to suspended first
			$getHostedServiceStaging |
			  Set-DeploymentStatus 'Suspended' |
			  Get-OperationStatus -WaitToComplete
		}	
	}

	Write-Output "Start swapping staging and production instances."

	# swap 'Staging' and 'Production'
	Get-Deployment staging -subscriptionId $subscriptionId -certificate $cert -serviceName $servicename | 
		Move-Deployment |
		Get-OperationStatus -WaitToComplete

	Write-Output "Done swapping staging and production instances."
	
	Write-Output "Spinning up production instances."
		
	# spin production up to 'running' if that wasn't already the case
	Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Production' |
		Set-DeploymentStatus 'Running' |
		Get-OperationStatus -WaitToComplete
		
	# the completion of previous action doesn't necessarily mean it's really ready, so check the status until it is 'Ready' and the name until it matches the one we used for our deployment
	$ready = $False
	while(!$ready)
	{
		$d = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId |
				Get-Deployment -Slot 'Production'
		$ready = ($d.RoleInstanceList[0].InstanceStatus -eq "Ready") -and ($d.Label -eq $buildLabel)
	}		
	
	Write-Output "Done spinning up production instances."
	
	# get 'staging' deployment status 
	$getHostedServiceStaging = Get-HostedService $servicename -Certificate $cert -SubscriptionId $subscriptionId | Get-Deployment -Slot 'Staging' 
	 
	# remove old 'staging' deploy if exists, which only is the case if we had a former 'Production' instance
	if ($getHostedServiceStaging.Status -ne $null)
	{
		Write-Output "Suspending staging instances."
		
		# set to suspended first
		$getHostedServiceStaging |
		  Set-DeploymentStatus 'Suspended' |
		  Get-OperationStatus -WaitToComplete

		Write-Output "Done suspending staging instances."
		  
		# if $removeStagingAfterSwap argument equals 'True' we remove staging; we only do this if $swapToProductionAfterDeploy equals 'True' as well
		if ($removeStagingAfterSwap -eq "True")
		{
			Write-Output "Removing staging instances."
		  
			# now remove it
			$getHostedServiceStaging |
			  Remove-Deployment |
			  Get-OperationStatus -WaitToComplete
			  
			Write-Output "Done removing staging instances."
		}
	}	
}

#remove temporary blob storage containers to avoid unnecessary usage and costs
Get-Container -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey -Filter 'mydeployments' | Clear-Container
Get-Container -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey -Filter 'wad-control-container' | Clear-Container
 
if ($error) { exit 888 }