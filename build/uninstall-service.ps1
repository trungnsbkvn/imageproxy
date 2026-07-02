<#
  uninstall-service.ps1 — stop and remove the imageproxy Windows service.
  Uses the binary's own SCM integration (no nssm). Run from an ELEVATED PowerShell.
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe  = Join-Path $here 'imageproxy.exe'
if (-not (Test-Path $exe)) { throw "imageproxy.exe not found next to this script." }

& $exe -service stop 2>$null | Out-Null
& $exe -service uninstall
Write-Host "Removed service 'imageproxy'. (Cache dir and logs are left in place.)"
