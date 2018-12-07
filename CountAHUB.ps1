#Sample scripts are not supported under any Microsoft standard support program or service. 
#The sample scripts are provided AS IS without warranty of any kind. Microsoft disclaims all 
#implied warranties including, without limitation, any implied warranties of merchantability
#or of fitness for a particular purpose. The entire risk arising out of the use or performance
#of the sample scripts and documentation remains with you. In no event shall Microsoft, its 
#authors, or anyone else involved in the creation, production, or delivery of the scripts be 
#liable for any damages whatsoever (including, without limitation, damages for loss of business
#profits, business interruption, loss of business information, or other pecuniary loss) arising
#out of the use of or inability to use the sample scripts or documentation, even if Microsoft 
#has been advised of the possibility of such damages.


# Install the Resource Graph (prerelease) module from PowerShell Gallery
#Install-Module -Name AzureRm.ResourceGraph -AllowPrerelease

#######
## EDIT HERE 
#######

$SubscriptionID = "<insert subscription id here>"

#######

#Get list of VM sizes of all valid commercial regions and store them in a table for lookup purposes
$VMSizes = Get-AzurermLocation | where-object {$_.Providers -contains 'Microsoft.Compute'} | get-azurermvmsize | Sort-Object -Property Name -Unique

$table = @{}

foreach ($key in $VMSizes){
    $vmsize = $key.Name
    $VMcores = $key.NumberOfCores
    $table[$vmsize] = $VMcores
}

#Collect list of VMs from Resource Graph
$searchresults = Search-AzureRMGraph -Subscription $SubscriptionID -query "where type =~ 'Microsoft.Compute/virtualMachines' | summarize count() by  tostring(properties.hardwareProfile.vmSize), tostring(properties.storageProfile.imageReference.sku), tostring(properties.licenseType)"
#$searchresults = Search-AzureRMGraph -query "where type =~ 'Microsoft.Compute/virtualMachines' | summarize count() by  tostring(properties.hardwareProfile.vmSize), tostring(properties.storageProfile.imageReference.sku), tostring(properties.licenseType)"

#Clean up output adding lookup data
$searchresults | Select-Object @{Name="VMSize";Expression={$_.properties_hardwareProfile_vmSize}},@{name="CoreCount";Expression={$table[$_.properties_hardwareProfile_vmSize]}},@{Name="Image SKU";Expression={$_.properties_storageProfile_imageReference_sku}},@{Name="License Type";Expression={$_.properties_licenseType}},@{Name="Count";Expression={$_.count_}},@{Name="Total Cores";Expression={($table[$_.properties_hardwareProfile_vmSize])*$_.count_}} |ft

#Build Non-AHUB Core Count
$val = $searchresults | Select-Object @{Name="License Type";Expression={$_.properties_licenseType}},@{Name="Total Cores";Expression={($table[$_.properties_hardwareProfile_vmSize])*$_.count_}} | Where-Object {$_."License Type" -ne "Windows_Server"} | Measure-Object -Property "Total Cores" -Sum
$NonAHUBCores = $Val.Sum
Write-host "Total Number of Non-AHUB cores: $NonAHUBCores"

write-host " "

#Build AHUB Core Count
$val = $searchresults | Select-Object @{Name="License Type";Expression={$_.properties_licenseType}},@{Name="Total Cores";Expression={($table[$_.properties_hardwareProfile_vmSize])*$_.count_}} | Where-Object {$_."License Type" -eq "Windows_Server"} | Measure-Object -Property "Total Cores" -Sum
$AHUBCores = $val.Sum
Write-host "Total Number of AHUB Cores: $AHUBCores"

#Total Number of VM using AHUB
$val = $searchresults | Where-Object {$_.properties_licenseType -eq 'Windows_Server'} | Measure-Object -Property "count_" -Sum
$TotalVMs = $val.Sum
Write-host "Total number of VMs using AHUB: $TotalVMs"

#Calculate the total license count need
$LicCoreNeeded = [int][math]::Ceiling(($AHUBCores / 16))
$LicVMNeeded = [int][math]::Ceiling(($TotalVMs / 2))

if ($LicCoreNeeded -gt $LicVMNeeded) {
    $TotalLics = $LicCoreNeeded
    } else {
    $TotalLics = $LicVMNeeded
    }
Write-host "Total number of licenses needed to cover AHUB machines: $TOtalLics" -ForegroundColor Cyan
