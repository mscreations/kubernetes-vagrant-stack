param (
    [parameter (Mandatory=$true)]
    [string]$Hostname,
    [parameter (Mandatory=$true)]
    [string]$ScopeId,
    [parameter (Mandatory=$true)]
    [string]$MACAddress,
    [parameter (Mandatory=$true)]
    [string]$IPAddress,
    [parameter (Mandatory=$true)]
    [string]$DHCPServer,
    [parameter (Mandatory=$true)]
    [string]$Username,
    [parameter (Mandatory=$true)]
    [string]$Password,
    [parameter (Mandatory=$false)]
    [switch]$RemoveReservation
)

Write-Host "----- Configure DHCP for Node -----"

$secPassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($Username, $secPassword)

Invoke-Command -ComputerName $DHCPServer -Credential $credential -ScriptBlock {
    param (
        [string]$Hostname,
        [string]$MACAddress,
        [string]$IPAddress,
        [string]$ScopeId,
        [bool]$RemoveReservation
    )

    Write-Host "Hostname: $Hostname"
    Write-Host "MAC Address: $MACAddress"
    Write-Host "IP Address: $IPAddress"

    $reservation = Get-DhcpServerv4Reservation -ScopeId $ScopeId | Where-Object {
        $_.ClientId -eq $MACAddress -or $_.Name -eq $Hostname -or $_.IPAddress -eq [IPAddress]$IPAddress
    }

    if ($reservation) {
        Write-Host "Removing existing reservation"
        # $reservation | Format-Table Name, ClientId, IPAddress
        Remove-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $reservation.ClientId
    }

    if (-not $RemoveReservation) {
        Write-Host "Adding new reservation"
        Add-DhcpServerv4Reservation -ScopeId $ScopeId -IPAddress $IPAddress -ClientId $MACAddress -Name $Hostname
    } else {
        Write-Host "Reservation removal flag is set. No new reservation will be added."
    }
} -ArgumentList $Hostname, $MACAddress, $IPAddress, $ScopeId, $RemoveReservation
