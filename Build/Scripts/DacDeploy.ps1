
# originally posted at https://github.com/JorritSalverda/msbuild-by-convention/

$dacpacPath = $args[0]
$deployServer = $args[1]
$deployUsername = $args[2]
$deployPassword = $args[3]
$deployTargetName = $args[4]

$connectionString = "Server=" + $deployServer + ";User Id=" + $deployUsername + ";Password=" + $deployPassword + ";Connection Timeout=60"
$sqlConnection = new-object System.Data.SqlClient.SqlConnection($connectionString)

## Open a Common.ServerConnection to the same instance.
$serverconnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($sqlConnection)
$serverconnection.Connect()
$dacstore = New-Object Microsoft.SqlServer.Management.Dac.DacStore($serverconnection)

## Load the DAC package file.
$fileStream = [System.IO.File]::Open($dacpacPath,[System.IO.FileMode]::OpenOrCreate)
$dacType = [Microsoft.SqlServer.Management.Dac.DacType]::Load($fileStream)

## Subscribe to the DAC deployment events.
$dacstore.add_DacActionStarted({Write-Host `n`nStarting at $(get-date) :: $_.Description})
$dacstore.add_DacActionFinished({Write-Host Completed at $(get-date) :: $_.Description})

## Deploy the DAC and create the database.
$dacName  = $deployTargetName
$evaluateTSPolicy = $true
$deployProperties = New-Object Microsoft.SqlServer.Management.Dac.DatabaseDeploymentProperties($serverconnection,$dacName)
$upgradeOptions = New-Object Microsoft.SqlServer.Management.Dac.DacUpgradeOptions

## todo check if database exists to determine whether to upgrade or install

if($dacstore.DacInstances.Contains($dacName))
{
	$dacstore.IncrementalUpgrade($dacName, $dacType, $upgradeOptions)
}
else
{
	$dacstore.install($dactype, $deployproperties, $evaluatetspolicy)
}

$fileStream.Close()
