<#
.SYNOPSIS
Converts a standard WireGuard configuration file into a WireSock configuration file.

.DESCRIPTION
This script takes a WireGuard configuration file as input and generates a client side selective tunnel DNS leak proof WireSock configuration file.  It assumes that the endpoint VPN server can serve DNS queries and is also DNS leak proof.
It prompts the user for custom routes and adds PostUp and PostDown scripts for DNS and routing management.

The PostUp script does the following:
1. Backs up current DNS settings for all active network adapters
2. Sets DNS to the specified server for all active adapters
3. Disables IPv6 on all active adapters
4. Adds routes for the VPN subnet and custom routes

The PostDown script does the following:
1. Restores original DNS settings for all network adapters
2. Re-enables IPv6 on all adapters
3. Removes the routes added by PostUp

.PARAMETER InputFile
The path to the input WireGuard configuration file. If not provided, the script will prompt for it.

.PARAMETER OutputFile
The path where the output WireSock configuration file will be saved. If not provided, the script will prompt for it.

.EXAMPLE
To run the script without changing the execution policy, use the following command in PowerShell:
powershell.exe -ExecutionPolicy Bypass -File .\WireSockConfigGenerator.ps1

.EXAMPLE
To run the script with parameters:
powershell.exe -ExecutionPolicy Bypass -File .\WireSockConfigGenerator.ps1 -InputFile "C:\path\to\wg0.conf" -OutputFile "C:\path\to\ws0.conf"

.NOTES
This script is designed for Windows environments. The -ExecutionPolicy Bypass parameter allows the script to run without changing the system-wide execution policy, which is more secure. Always ensure you trust the script before running it this way.

Author: Anton Luu
Date: September 7, 2024
License: GNU General Public License v2.0

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

Full license text can be found at: https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InputFile,
    [Parameter(Mandatory=$false)]
    [string]$OutputFile
)

# Function to display warnings with only "Warning:" and the faulty entry in red
function Write-ColorWarning {
    param([string]$message, [string]$faultyEntry = "")
    Write-Host "Warning: " -ForegroundColor Red -NoNewline
    if ($faultyEntry) {
        $parts = $message -split [regex]::Escape($faultyEntry)
        Write-Host $parts[0] -NoNewline
        Write-Host $faultyEntry -ForegroundColor Red -NoNewline
        Write-Host $parts[1]
    } else {
        Write-Host $message
    }
}

# Default file names
$defaultInputFile = "wg0.conf"
$defaultOutputFile = "ws0.conf"

# Prompt for input file
if (-not $InputFile) {
    $InputFile = Read-Host "Enter the path to the input WireGuard configuration file (default: $defaultInputFile)"
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        $InputFile = $defaultInputFile
    }
}

# Prompt for output file
if (-not $OutputFile) {
    $OutputFile = Read-Host "Enter the path for the output WireSock configuration file (default: $defaultOutputFile)"
    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $OutputFile = $defaultOutputFile
    }
}

# Read the input WireGuard configuration file
$config = Get-Content $InputFile -Raw

# Parse the existing configuration
$interface = [regex]::Match($config, '\[Interface\](.*?)(?=\[Peer\]|\z)', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value.Trim()
$peer = [regex]::Match($config, '\[Peer\](.*)', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value.Trim()

# Extract DNS server from the WireGuard config
$dnsServer = [regex]::Match($interface, 'DNS\s*=\s*(.*)').Groups[1].Value.Trim()

if ([string]::IsNullOrWhiteSpace($dnsServer)) {
    Write-ColorWarning "No DNS server found in the WireGuard config. Some features may not work correctly."
}

# Remove initial AllowedIPs
$peer = $peer -replace 'AllowedIPs\s*=\s*0\.0\.0\.0/0,\s*::/0\s*\n?', ''

# Prompt for allowed IPs and custom routes
$allowedIPs = @()
Write-Host "Enter IP ranges, websites, or IPs to route through the VPN."
Write-Host "Please enter only one item per line. Press Enter on an empty line to finish."
Write-Host "Examples:"
Write-Host "  10.0.0.0/24"
Write-Host "  example.com"
Write-Host "  203.0.113.0"
do {
    $route = Read-Host "Route"
    if ($route -ne "") {
        $allowedIPs += $route
    }
} while ($route -ne "")

# Process allowed IPs and custom routes
$processedIPs = @()
foreach ($route in $allowedIPs) {
    if ($route -match "^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$") {
        # IPv4 address or range
        $processedIPs += $route
    } elseif ($route -match "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$") {
        # FQDN
        try {
            $ip = Resolve-DnsName $route -Type A -ErrorAction Stop | Select-Object -ExpandProperty IPAddress -First 1
            if ($ip) {
                $processedIPs += "$ip/32"
            }
        } catch {
            Write-ColorWarning "Could not resolve FQDN $route. Skipping." $route
        }
    } elseif ($route -match ":") {
        # IPv6 address or range
        Write-ColorWarning "IPv6 address $route detected. Skipping as per requirements." $route
    } else {
        Write-ColorWarning "Invalid input $route. Skipping." $route
    }
}

$allowedIPsString = $processedIPs -join ", "

# Prepare PostUp and PostDown scripts (without comments)
$postUp = "PostUp = powershell -Command `"`$adapters = Get-NetAdapter | Where-Object {`$_.Status -eq 'Up'}; `$global:dnsBackup = @{}; foreach (`$adapter in `$adapters) { `$dnsServers = (Get-DnsClientServerAddress -InterfaceAlias `$adapter.Name -AddressFamily IPv4).ServerAddresses; if (`$dnsServers) { `$global:dnsBackup[`$adapter.Name] = `$dnsServers; Set-DnsClientServerAddress -InterfaceAlias `$adapter.Name -ServerAddresses $dnsServer }; Disable-NetAdapterBinding -InterfaceAlias `$adapter.Name -ComponentID ms_tcpip6 }; `$global:dnsBackup | ConvertTo-Json | Set-Content 'C:\Windows\Temp\dns_backup.json'; $($processedIPs | ForEach-Object { "route add $_ mask 255.255.255.255 $dnsServer metric 5; " })`""

$postDown = "PostDown = powershell -Command `"if (Test-Path 'C:\Windows\Temp\dns_backup.json') { `$dnsBackup = Get-Content 'C:\Windows\Temp\dns_backup.json' | ConvertFrom-Json; foreach (`$adapter in `$dnsBackup.PSObject.Properties) { Set-DnsClientServerAddress -InterfaceAlias `$adapter.Name -ServerAddresses `$adapter.Value; Enable-NetAdapterBinding -InterfaceAlias `$adapter.Name -ComponentID ms_tcpip6 }; Remove-Item 'C:\Windows\Temp\dns_backup.json' }; $($processedIPs | ForEach-Object { "route delete $_ mask 255.255.255.255 $dnsServer; " })`""

# Construct the new WireSock configuration
$newConfig = @"
[Interface]
$interface
$postUp
$postDown

[Peer]
$peer
AllowedIPs = $allowedIPsString
"@

# Write the new configuration to the output file
$newConfig | Set-Content $OutputFile

Write-Host "WireSock configuration has been generated and saved to $OutputFile" -ForegroundColor Green