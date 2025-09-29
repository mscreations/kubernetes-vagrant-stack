param (
    [parameter (Mandatory=$true)]
    [string]$VMName
)

Write-Host "Resetting UUID for $VMName"

$MSVM = gwmi -Namespace root\virtualization\v2 -Class msvm_computersystem -Filter "ElementName = '$VMName'"
 
# get current settings object
$MSVMSystemSettings = $null
foreach($SettingsObject in $MSVM.GetRelated('msvm_virtualsystemsettingdata'))
{
    $MSVMSystemSettings = [System.Management.ManagementObject]$SettingsObject
}
 
# assign a new id
$MSVMSystemSettings['BIOSGUID'] = "{$(([System.Guid]::NewGuid()).Guid.ToUpper())}"
 
$VMMS = gwmi -Namespace root\virtualization\v2 -Class msvm_virtualsystemmanagementservice
# prepare and assign parameters
$ModifySystemSettingsParameters = $VMMS.GetMethodParameters('ModifySystemSettings')
$ModifySystemSettingsParameters['SystemSettings'] = $MSVMSystemSettings.GetText([System.Management.TextFormat]::CimDtd20)
# invoke modification
$VMMS.InvokeMethod('ModifySystemSettings', $ModifySystemSettingsParameters, $null)