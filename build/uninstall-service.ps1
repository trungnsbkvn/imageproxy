<#
  uninstall-service.ps1 — stop and remove the imageproxy Windows service.
  Works for BOTH install methods (native self-register and nssm): sc.exe removes a
  service by name regardless of how it was created, and deleting the service key also
  clears any nssm parameters under it. Run from an ELEVATED PowerShell.
#>
$ErrorActionPreference = 'Stop'
$ServiceName = 'imageproxy'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Run this in an ELEVATED PowerShell (Administrator)." }

if (-not (Get-Service $ServiceName -ErrorAction SilentlyContinue)) {
  Write-Host "Service '$ServiceName' not found — nothing to do."
  return
}

& sc.exe stop   $ServiceName 2>$null | Out-Null
Start-Sleep -Milliseconds 500
& sc.exe delete $ServiceName

Write-Host "Removed service '$ServiceName' (works for native and nssm installs)."
Write-Host "(Cache dir and logs are left in place; nssm.exe, if used, remains on disk.)"
