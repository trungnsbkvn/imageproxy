<#
  uninstall-service.ps1 — stop and remove the imageproxy Windows service (NSSM).
  Run from an ELEVATED PowerShell.
#>
$ErrorActionPreference = 'Stop'
$ServiceName = 'imageproxy'

$nssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
if (-not $nssmCmd) { throw "nssm not found on PATH." }
$nssm = $nssmCmd.Source

& $nssm stop   $ServiceName 2>$null | Out-Null
& $nssm remove $ServiceName confirm
Write-Host "Removed service '$ServiceName'. (Cache dir and logs are left in place.)"
