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


###########
## CountAHUB.ps1
###########
## Description: This script uses Azure Resource Graph to query the Azure subscription you specify or
##   all of the subscriptions that you have access to with the intent of counting the number of cores 
##   and VMs to caluclate the number of licenses needed to cover those VMs that have AHUB enabled.
###########
## IMPORTANT NOTES:
##   1.) This script is meant to be a way to estimate. Please leverage other means to officially
##   account for your license usage.
##
##       For more information on Azure Hybrid Use Benefits, see: 
##       https://azure.microsoft.com/en-us/pricing/hybrid-benefit/
##
##   2.) In order to run this script you will need to install the Resource Graph modules from 
##   the Powershell Gallery by using the following command:
##
##       Install-Module -name az.resourcegraph -AllowClobber -Force
##
##   3.) The Resource Graph will only let you see what you have access to be able to see within a
##   given subscription.

###########
## EDIT HERE
##   The SubscriptionID variable can eitehr hold a single subscription ID or could be blank to 
##   pull all of the subscriptions that you have access to. 
##
## EXAMPLES:
##
##   $SubscriptionID = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
##      This will only search the specific subscription ID.
##
##
##   $SubscriptionID = ""
##      This will search all of the subscriptions that you have access to.
##
###########

#$SubscriptionID = "<insertSubscriptionIDHere>"
$SubscriptionID = ""

#######

#Get list of VM sizes of all valid commercial regions and store them in a table for lookup purposes
$VMSizes = Get-AzLocation | where-object {$_.Providers -contains 'Microsoft.Compute'} | get-azvmsize -ErrorAction SilentlyContinue | Sort-Object -Property Name -Unique

$table = @{}

foreach ($key in $VMSizes){
    $vmsize = $key.Name
    $VMcores = $key.NumberOfCores
    $table[$vmsize] = $VMcores
}

#Collect list of VMs from Resource Graph
if ($SubscriptionID -eq "") {
    $searchresults = Search-AzGraph -query "where type =~ 'Microsoft.Compute/virtualMachines' | summarize count() by  tostring(properties.hardwareProfile.vmSize), tostring(properties.storageProfile.imageReference.sku), tostring(properties.licenseType)"
} Else {
    $searchresults = Search-AzGraph -Subscription $SubscriptionID -query "where type =~ 'Microsoft.Compute/virtualMachines' | summarize count() by  tostring(properties.hardwareProfile.vmSize), tostring(properties.licenseType)"
}

#Clean up output adding lookup data
$searchresults | Select-Object @{Name="VMSize";Expression={$_.properties_hardwareProfile_vmSize}},@{name="CoreCount";Expression={$table[$_.properties_hardwareProfile_vmSize]}},@{Name="License Type";Expression={$_.properties_licenseType}},@{Name="Count";Expression={$_.count_}},@{Name="Total Cores";Expression={($table[$_.properties_hardwareProfile_vmSize])*$_.count_}} | Format-Table -AutoSize @{Name="VMSize";Expression={$_.VMSize};Alignment="left"},@{name="CoreCount";Expression={$_.CoreCount};Alignment="center"},@{Name="License Type";Expression={$_."License Type"};Alignment="left"},@{Name="VM Count";Expression={$_."Count"};Alignment="center"},@{Name="Total Cores";Expression={$_."Total Cores"};Alignment="center"}

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
write-host "****************************************************************************************" -Foregroundcolor cyan
Write-host "Total number of licenses needed to cover AHUB machines: $TOtalLics" -ForegroundColor Cyan
write-host "****************************************************************************************" -Foregroundcolor cyan
write-host ""
write-host "NOTE: With Software Assurance:" -ForegroundColor Cyan
write-host "  - Standard licenses can be used either on premise or in Azure." -ForegroundColor Cyan
write-host "  - Datacenter licenses can be used both on premise and in Azure at the same time." -ForegroundColor Cyan
write-host "This makes Azure the cheapest place to run Windows workloads." -ForegroundColor Cyan
