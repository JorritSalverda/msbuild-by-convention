
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

function PublishAndSwap()
{
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot "Staging" -ErrorVariable a -ErrorAction silentlycontinue 
    if ($a[0] -ne $null)
    {
        Write-Output "$(Get-Date -f $timeStampFormat) - No deployment is detected. Creating a new deployment. "
    }
	
    #check for existing deployment and then either upgrade, delete + deploy, or cancel according to $alwaysDeleteExistingDeployments and $enableDeploymentUpgrade boolean variables
    if ($deployment.Name -ne $null)
    {
		Write-Output "$(Get-Date -f $timeStampFormat) - Deployment exists in $servicename.  Deleting deployment."
		DeleteDeployment("Staging")
    }
	
	CreateNewDeployment("Staging")
	
	if ($swapAfterDeploy -eq "True")
	{
		SpinUpDeployment("Staging")
		SwapDeployments
		SpinUpDeployment("Production")
		if ($deleteStagingAfterSwap -eq "True") 
		{
			DeleteDeployment("Staging")
		}
	}
}

function PublishAndUpgrade()
{
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot "Production" -ErrorVariable a -ErrorAction silentlycontinue 
    if ($a[0] -ne $null)
    {
        Write-Output "$(Get-Date -f $timeStampFormat) - No deployment is detected. Creating a new deployment. "
    }
    #check for existing deployment and then either upgrade, delete + deploy, or cancel according to $alwaysDeleteExistingDeployments and $enableDeploymentUpgrade boolean variables
    if ($deployment.Name -ne $null)
    {
		UpgradeDeployment("Production")		
    } 
	else 
	{
		CreateNewDeployment("Production")	
    }
	SpinUpDeployment("Production")
}

function CreateNewDeployment($slot)
{
    write-progress -id 3 -activity "Creating New Deployment" -Status "In progress"
    Write-Output "$(Get-Date -f $timeStampFormat) - Creating New Deployment: In progress"
	
    $opstat = New-AzureDeployment -Slot $slot -Package $packageLocation -Configuration $cloudConfigLocation -label $deploymentLabel -ServiceName $serviceName

    $completeDeployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $completeDeploymentID = $completeDeployment.deploymentid

    write-progress -id 3 -activity "Creating New Deployment" -completed -Status "Complete"
    Write-Output "$(Get-Date -f $timeStampFormat) - Creating New Deployment: Complete, Deployment ID: $completeDeploymentID"

    StartInstances($slot)
}

function UpgradeDeployment($slot)
{
    write-progress -id 3 -activity "Upgrading Deployment" -Status "In progress"
    Write-Output "$(Get-Date -f $timeStampFormat) - Upgrading Deployment: In progress"

    # perform Update-Deployment
    $setdeployment = Set-AzureDeployment -Upgrade -Slot $slot -Package $packageLocation -Configuration $cloudConfigLocation -label $deploymentLabel -ServiceName $serviceName -Force

    $completeDeployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $completeDeploymentID = $completeDeployment.deploymentid

    write-progress -id 3 -activity "Upgrading Deployment" -completed -Status "Complete"
    Write-Output "$(Get-Date -f $timeStampFormat) - Upgrading Deployment: Complete, Deployment ID: $completeDeploymentID"
}

function DeleteDeployment($slot)
{
    write-progress -id 2 -activity "Deleting Deployment" -Status "In progress"
    Write-Output "$(Get-Date -f $timeStampFormat) - Deleting Deployment: In progress"

    #WARNING - always deletes with force
    $removeDeployment = Remove-AzureDeployment -Slot $slot -ServiceName $serviceName -Force

    write-progress -id 2 -activity "Deleting Deployment: Complete" -completed -Status $removeDeployment
    Write-Output "$(Get-Date -f $timeStampFormat) - Deleting Deployment: Complete"
}

function StartInstances($slot)
{
    write-progress -id 4 -activity "Starting Instances" -status "In progress"
    Write-Output "$(Get-Date -f $timeStampFormat) - Starting Instances: In progress"

    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $runstatus = $deployment.Status

    if ($runstatus -ne 'Running') 
    {
        $run = Set-AzureDeployment -Slot $slot -ServiceName $serviceName -Status Running
    }
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $oldStatusStr = @("") * $deployment.RoleInstanceList.Count

    while (-not(AllInstancesRunning($deployment.RoleInstanceList)))
    {
        $i = 1
        foreach ($roleInstance in $deployment.RoleInstanceList)
        {
            $instanceName = $roleInstance.InstanceName
            $instanceStatus = $roleInstance.InstanceStatus

            if ($oldStatusStr[$i - 1] -ne $roleInstance.InstanceStatus)
            {
                $oldStatusStr[$i - 1] = $roleInstance.InstanceStatus
                Write-Output "$(Get-Date -f $timeStampFormat) - Starting Instance '$instanceName': $instanceStatus"
            }

            write-progress -id (4 + $i) -activity "Starting Instance '$instanceName'" -status "$instanceStatus"
            $i = $i + 1
        }

        sleep -Seconds 1

        $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    }

    $i = 1
    foreach ($roleInstance in $deployment.RoleInstanceList)
    {
        $instanceName = $roleInstance.InstanceName
        $instanceStatus = $roleInstance.InstanceStatus

        if ($oldStatusStr[$i - 1] -ne $roleInstance.InstanceStatus)
        {
            $oldStatusStr[$i - 1] = $roleInstance.InstanceStatus
            Write-Output "$(Get-Date -f $timeStampFormat) - Starting Instance '$instanceName': $instanceStatus"
        }

        $i = $i + 1
    }

    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $opstat = $deployment.Status 

    write-progress -id 4 -activity "Starting Instances" -completed -status $opstat
    Write-Output "$(Get-Date -f $timeStampFormat) - Starting Instances: $opstat"
}

function AllInstancesRunning($roleInstanceList)
{
    foreach ($roleInstance in $roleInstanceList)
    {
        if ($roleInstance.InstanceStatus -ne "ReadyRole")
        {
            return $false
        }
    }

    return $true
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
if ($enableDeploymentUpgrade -eq "True")
{
	Write-Output "$(Get-Date -f $timeStampFormat) - Preparing in-place upgrade of $deploymentLabel for $subscriptionname with Subscription ID $subscriptionid."

	PublishAndUpgrade
}
else
{
	Write-Output "$(Get-Date -f $timeStampFormat) - Preparing deployment of $deploymentLabel for $subscriptionname with Subscription ID $subscriptionid."

	PublishAndSwap
}

$deployment = Get-AzureDeployment -slot "Production" -serviceName $servicename
$deploymentUrl = $deployment.Url

Write-Output "$(Get-Date -f $timeStampFormat) - Created Cloud Service with URL $deploymentUrl."
Write-Output "$(Get-Date -f $timeStampFormat) - Azure Cloud Service deploy script finished."
