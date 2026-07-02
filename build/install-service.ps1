<#
  install-service.ps1 — install imageproxy as a NATIVE Windows service (no nssm).

  The binary registers ITSELF with the Windows Service Control Manager via
  `imageproxy.exe -service install`, so no third-party wrapper is needed.
  Run from an ELEVATED PowerShell in this folder, after editing the CONFIG block.
  Compatible with Windows PowerShell 5.1 and PowerShell 7+.
#>
$ErrorActionPreference = 'Stop'

# ── CONFIG (edit these) ─────────────────────────────────────────────────────
$ServiceName  = 'imageproxy'                           # the name the binary registers
$Addr         = '127.0.0.1:8080'                       # loopback: only IIS reaches it
$AllowHosts   = 'luatsumienbac.vn'                     # lock the source origin
$CacheDir     = 'D:/media/luatsumienbac/_imgcache'     # forward slashes are safest
$Timeout      = '20s'
$SignatureKey = ''                                     # '' = unsigned (allowHosts still protects)
# ────────────────────────────────────────────────────────────────────────────

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe  = Join-Path $here 'imageproxy.exe'
if (-not (Test-Path $exe)) {
  throw "imageproxy.exe not found next to this script. Build it first: ..\build.ps1 (or see ..\DEPLOY.md)."
}

# Installing a service requires elevation.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Run this in an ELEVATED PowerShell (Administrator)." }

$logPath = Join-Path $here 'imageproxy.log'
$svcArgs = @('-addr', $Addr, '-allowHosts', $AllowHosts, '-cache', $CacheDir, '-timeout', $Timeout, '-logFile', $logPath)
if ($SignatureKey -ne '') { $svcArgs += @('-signatureKey', $SignatureKey) }

# Remove any previous install (ignore errors if absent).
& $exe -service stop      2>$null | Out-Null
& $exe -service uninstall 2>$null | Out-Null

Write-Host "Installing service '$ServiceName' (native SCM, no nssm) ..."
& $exe -service install @svcArgs
if ($LASTEXITCODE -ne 0) { throw "install failed ($LASTEXITCODE)." }

# Native crash recovery via built-in sc.exe: restart after 5s, reset the fail count daily.
& sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null
& sc.exe config  $ServiceName start= auto | Out-Null   # start at boot

& $exe -service start
Write-Host ""
Write-Host "Installed + started '$ServiceName' — a real Windows service (services.msc)."
Write-Host "  Status : sc.exe query $ServiceName"
Write-Host "  Logs   : $logPath"
Write-Host "  Test   : curl.exe http://$Addr/health-check   # -> OK"
Write-Host "Next: add the IIS /img rule + set IMAGE_RESIZER=imageproxy (see ..\DEPLOY.md)."
