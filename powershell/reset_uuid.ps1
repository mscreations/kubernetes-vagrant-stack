param (
    [parameter (Mandatory=$true)]
    [string]$VMName
)

Write-Host "Resetting UUID for $VMName"

$MSVM = Get-WMIObject -Namespace root\virtualization\v2 -Class msvm_computersystem -Filter "ElementName = '$VMName'"
 
# get current settings object
$MSVMSystemSettings = $null
foreach($SettingsObject in $MSVM.GetRelated('msvm_virtualsystemsettingdata'))
{
    $MSVMSystemSettings = [System.Management.ManagementObject]$SettingsObject
}
 
# assign a new id
$new_id = ([System.Guid]::NewGuid()).Guid.Toupper()
$MSVMSystemSettings['BIOSGUID'] = "{$new_id}"
 
$VMMS = Get-WMIObject -Namespace root\virtualization\v2 -Class msvm_virtualsystemmanagementservice
# prepare and assign parameters
$ModifySystemSettingsParameters = $VMMS.GetMethodParameters('ModifySystemSettings')
$ModifySystemSettingsParameters['SystemSettings'] = $MSVMSystemSettings.GetText([System.Management.TextFormat]::CimDtd20)
# invoke modification
$VMMS.InvokeMethod('ModifySystemSettings', $ModifySystemSettingsParameters, $null) | Out-Null

Write-Host "Reset UUID to $new_id"