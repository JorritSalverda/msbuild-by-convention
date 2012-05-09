msbuild-by-convention
=====================

MSBuild based set of build scripts that favors convention over configuration. This is done by giving your projects specific names.

This content is released under the https://github.com/JorritSalverda/msbuild-by-convention/blob/master/Build/Scripts/LICENSE.txt MIT License.

**Set up:**  
  
* clone repository
* download at least the following tools and save the files mentioned in the corresponding dir.txt files to the /Build/Tools/ subdirectories
  
* compile:
	* optipng-0.7.1-win32
	* Jpegtran
	* Yahoo.Yui.Compressor.v1.6.0.2
	* Windows.Azure.Tools.v1.6
  
* run unit / integration tests
	* NUnit-2.6.0.12051
	* Machine.Specifications.0.5.3.0
  
* deploy visual studio database project
	* Vs2010DbCmd
  
* deploy data-tier application	
	* SqlPowershell-10.50.1600.1
  
**Usage:**  
  
All commands should be run from Build/Scripts/  
  
* compile
	* msbuild.exe targets.msbuild /t:Build /p:BuildVersion=1.0.0.{buildNumber}
  
* run unit tests (depends on compile)
	* msbuild.exe targets.msbuild /t:RunUnitTests /p:BuildVersion=1.0.0.{buildNumber}
  
* create release (depends on compile)
	* msbuild.exe targets.msbuild /t:Release /p:BuildVersion=1.0.0.{buildNumber}
	* (save Build/Releases/** as release artefact)
  
* run integration tests (depends on compile)
	* msbuild.exe targets.msbuild /t:RunIntegrationTests /p:BuildVersion=1.0.0.{buildNumber}
  
* deploy visual studio database project or data-tier application (depends on compile + create release)
	* msbuild.exe targets.msbuild /t:Deploy /p:BuildVersion=1.0.0.{buildNumber} /p:DeployEnvironment="{INT|UAT|ACC|PROD}" /p:ProjectToDeploy='{database project name}' /p:DeployServer='{remote server}' /p:DeployTargetName='{remote database name}' /p:DeployUsername='{remote admin username}' /p:DeployPassword='{remote admin password}'
  
* deploy azure role (depends on compile + create release)
	* create certificate, upload to azure as management certificate and store in /Build/Scripts as AzureManagementCertificate.cer and AzureManagementCertificate.pfx
	* msbuild.exe targets.msbuild /t:Deploy /p:BuildVersion=1.0.0.{buildNumber} /p:DeployEnvironment="{INT|UAT|ACC|PROD}" /p:ProjectToDeploy="{azure project name}" /p:AzureSubscriptionID="{azure subscription id}" /p:AzureCertificatePassword="{management certificate password}" /p:AzureHostedServiceName="{hosted service name}" /p:AzureStorageAccountName="{azure storage account}" /p:AzureStorageAccountKey="{secret key for azure storage account}" /p:AzureSwapToProductionAfterDeploy="{False|True}" /p:AzureRemoveStagingAfterSwap="{False|True}"