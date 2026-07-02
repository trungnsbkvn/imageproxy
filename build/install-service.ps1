<#
  install-service.ps1 — install imageproxy as a Windows service. Two methods:

    .\install-service.ps1                 # NATIVE (default): the binary self-registers
                                          #   with the SCM via `-service install` (no deps)
    .\install-service.ps1 -Method nssm    # via NSSM (requires nssm.exe on PATH)

  Run from an ELEVATED PowerShell in this folder, after editing the CONFIG block.
  Compatible with Windows PowerShell 5.1 and PowerShell 7+.
#>
param(
  [ValidateSet('native', 'nssm')]
  [string]$Method = 'native',
  # Full path to nssm.exe (only for -Method nssm). If omitted, nssm must be on PATH.
  [string]$NssmPath = ''
)
$ErrorActionPreference = 'Stop'

# ── CONFIG (edit these) ─────────────────────────────────────────────────────
$ServiceName  = 'imageproxy'
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

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Run this in an ELEVATED PowerShell (Administrator)." }

$logPath = Join-Path $here 'imageproxy.log'
# Runtime flags shared by both methods (as an array — handles spaces in paths).
$svcArgs = @('-addr', $Addr, '-allowHosts', $AllowHosts, '-cache', $CacheDir, '-timeout', $Timeout, '-logFile', $logPath)
if ($SignatureKey -ne '') { $svcArgs += @('-signatureKey', $SignatureKey) }

if ($Method -eq 'nssm') {
  if ($NssmPath -ne '') {
    if (-not (Test-Path $NssmPath)) { throw "NssmPath not found: $NssmPath" }
    $nssm = (Resolve-Path $NssmPath).Path
  }
  else {
    $nssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
    if (-not $nssmCmd) {
      throw "nssm not found on PATH. Pass -NssmPath 'C:\tools\nssm\nssm.exe', install it (choco/scoop), or omit -Method for the native install."
    }
    $nssm = $nssmCmd.Source
  }

  # Quote paths so spaces in $CacheDir/$logPath survive as a single AppParameters string.
  $nssmParams = "-addr $Addr -allowHosts $AllowHosts -cache `"$CacheDir`" -timeout $Timeout -logFile `"$logPath`""
  if ($SignatureKey -ne '') { $nssmParams += " -signatureKey $SignatureKey" }

  & $nssm stop   $ServiceName 2>$null | Out-Null
  & $nssm remove $ServiceName confirm 2>$null | Out-Null

  Write-Host "Installing service '$ServiceName' via NSSM ..."
  & $nssm install $ServiceName $exe
  & $nssm set $ServiceName AppDirectory $here
  & $nssm set $ServiceName AppParameters $nssmParams
  & $nssm set $ServiceName AppStderr (Join-Path $here 'err.log')   # crash backstop; normal logs go to imageproxy.log
  & $nssm set $ServiceName AppExit Default Restart
  & $nssm set $ServiceName Start SERVICE_AUTO_START
  & $nssm start $ServiceName
  & $nssm status $ServiceName
}
else {
  # NATIVE: the binary registers itself with the Windows SCM (no nssm).
  & $exe -service stop      2>$null | Out-Null
  & $exe -service uninstall 2>$null | Out-Null

  Write-Host "Installing service '$ServiceName' (native SCM, no nssm) ..."
  & $exe -service install @svcArgs
  if ($LASTEXITCODE -ne 0) { throw "install failed ($LASTEXITCODE)." }

  # Native crash recovery + auto-start via built-in sc.exe.
  & sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null
  & sc.exe config  $ServiceName start= auto | Out-Null
  & $exe -service start
}

Write-Host ""
Write-Host "Installed + started '$ServiceName' via '$Method' — a real Windows service (services.msc)."
Write-Host "  Status : sc.exe query $ServiceName"
Write-Host "  Logs   : $logPath"
Write-Host "  Test   : curl.exe http://$Addr/health-check   # -> OK"
Write-Host "Uninstall (either method): .\uninstall-service.ps1"
Write-Host "Next: add the IIS /img rule + set IMAGE_RESIZER=imageproxy (see ..\DEPLOY.md)."
