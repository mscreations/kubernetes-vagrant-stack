param (
    [Parameter(Mandatory = $true)]
    [string]$VMName
)

# Try to get the VM
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if ($null -ne $vm) {
    "Created"
} else {
    "NotCreated"
}
