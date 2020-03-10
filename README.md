# countAHUB
Powershell script to count the licenses required to cover your Azure VMs running with the AHUB flag.

# Usage Information
There are a few things to keep in mind when running this script:
1. You have to be logged in to Azure via [PowerShell](https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-3.5.0#sign-in-interactively) before using this script. This is also using some of the older commands, so you may also need to issue the  [Enable-AzureRmAlias](https://docs.microsoft.com/en-us/powershell/module/az.accounts/enable-azurermalias?view=azps-3.5.0) command
1. Update the $SubscriptionID variable line with the subscription ID that you want to search or clear it out to search all of the subscriptions that you have access.
1. Additional information on how to calculate Azure Hybrid Use Benefits can be found [here](https://docs.microsoft.com/en-us/windows-server/get-started/azure-hybrid-benefit).
