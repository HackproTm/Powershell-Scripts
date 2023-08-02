
# ARM TEMPLATE INFO: https://learn.microsoft.com/en-us/azure/templates/
# AZURE POWERSHELL INFO: https://learn.microsoft.com/en-us/powershell/module/?view=azps-9.7.1

#####################################
# Connect using an App Registration #
#####################################
# Command: https://learn.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount?view=azps-9.7.1

$TenantId = "MyTenantId"
$SubscriptionId = "MySubscriptionId"
$ApplicationId = "MyApplicationId"
$ApplicationPassword = "**********************************"
$ApplicationSecuredPassword = ConvertTo-SecureString -String $ApplicationPassword -AsPlainText

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $ApplicationSecuredPassword
Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Subscription $subscriptionId -Credential $Credential


#########################################
# Connect using a Active Directory user #
#########################################

$TenantId = "MyTenantId"
$SubscriptionId = "MySubscriptionId"
$User = "MyUser"
$UserPassword = "***********"
$UserSecurePassword = ConvertTo-SecureString -String $UserPassword -AsPlainText -Force

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $UserSecurePassword
Connect-AzAccount -Tenant $TenantId -Subscription $subscriptionId -Credential $Credential


##################################################################
# Connect using credential provides by Web Browser (MFA Enabled) #
##################################################################

Connect-AzAccount -UseDeviceAuthentication


#########################
# Create Resource Group #
#########################
# ARM Template: https://learn.microsoft.com/en-us/azure/templates/microsoft.resources/resourcegroups?pivots=deployment-language-arm-template
# Command: https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroup

$RGName = "MY-RESOURCE-GROUP-NAME"
$RLocation = "East US 2"

New-AzResourceGroup -Name "$RGName" -Location "$RLocation"


##############################
# Create PowerShell Function #
##############################
# https://learn.microsoft.com/en-us/powershell/scripting/learn/ps101/09-functions?view=powershell-7.3

# function CheckResourceExist ([string] $ResourceName, [string]$ResourceGroup = "") {
function CheckResourceExist {
  param (
    [Parameter(Mandatory)]
    [string]$ResourceName,

    [string]$ResourceGroup = ""
  )

  $Parameters = @{
    Name = "$ResourceName"
    ErrorAction = "SilentlyContinue"
  }

  if ($ResourceGroup) {
    $Parameters += @{
      ResourceGroupName = $ResourceGroup
    }
  }

  $Exist = Get-AzResource @Parameters

  return $Exist ? $true : $false
}


####################
# Create Key Vault #
####################
# ARM Template: https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-arm-template
# Command: https://learn.microsoft.com/en-us/powershell/module/az.keyvault/new-azkeyvault

$KVName = "mykeyvault"
New-AzKeyVault -Name "$KVName" -ResourceGroupName "$RGName" -EnabledForTemplateDeployment -Sku Standard -PublicNetworkAccess Enabled -SoftDeleteRetentionInDays 7

# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7.2#splatting-with-hash-tables
$Parameters = @{
  Name = "$KVName"
  ResourceGroupName = "$RGName"
  EnabledForTemplateDeployment = true
  Sku = "Standard"
  PublicNetworkAccess = "Enabled"
  SoftDeleteRetentionInDays = 7
}
New-AzKeyVault @Parameters

New-AzResourceLock -LockLevel CanNotDelete -LockNotes "Please Don't Delete" -LockName "kv-lock" -ResourceName "$KVName" -ResourceGroupName "$RGName" -ResourceType "Microsoft.Keyvault/vaults"

Remove-AzKeyVault -VaultName $KVName


##########################
# Create Storage Account #
##########################
# ARM Template: https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts?pivots=deployment-language-arm-template
# Command: https://learn.microsoft.com/en-us/powershell/module/az.storage/new-azstorageaccount?view=azps-9.7.1

$SAName = "mystorageaccount"

if (! (CheckResourceExist -ResourceName $SAName)) {
  New-AzStorageAccount -ResourceGroupName "$RGName" `
    -Name "$SAName" `
    -Location "$RLocation" `
    -SkuName "Standard_LRS" `
    -Kind "StorageV2" `
    -AccessTier Hot `
    -PublicNetworkAccess "Enabled"
} else {
  Write-Host "The Storage Account $SAName already exists."
}

