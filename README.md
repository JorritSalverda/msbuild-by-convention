## msbuild-by-convention

MSBuild based set of build scripts that favors convention over configuration. This is done by giving your projects specific names.

This content is released under the https://github.com/JorritSalverda/msbuild-by-convention/blob/master/LICENSE MIT License.

### Get started:
  
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
  
### How to use:
  
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
	
## License

(MIT License)

Copyright (C) 2012 Jorrit Salverda

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.  