<#
  install-service.ps1 — install imageproxy as a Windows service via NSSM.

  Run from an ELEVATED PowerShell in this folder, after editing the CONFIG block.
  Requires nssm on PATH (https://nssm.cc/ , or: choco install nssm / scoop install nssm).
  Compatible with Windows PowerShell 5.1 and PowerShell 7+.
#>
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

$nssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
if (-not $nssmCmd) {
  throw "nssm not found on PATH. Install it (https://nssm.cc/ , choco install nssm, or scoop install nssm)."
}
$nssm = $nssmCmd.Source

$params = "-addr $Addr -allowHosts $AllowHosts -cache $CacheDir -timeout $Timeout"
if ($SignatureKey -ne '') { $params = "$params -signatureKey $SignatureKey" }

Write-Host "Installing service '$ServiceName' -> $exe"
& $nssm stop   $ServiceName 2>$null | Out-Null
& $nssm remove $ServiceName confirm 2>$null | Out-Null
& $nssm install $ServiceName $exe
& $nssm set $ServiceName AppDirectory $here
& $nssm set $ServiceName AppParameters $params
& $nssm set $ServiceName AppStdout (Join-Path $here 'out.log')
& $nssm set $ServiceName AppStderr (Join-Path $here 'err.log')
& $nssm set $ServiceName AppRotateFiles 1
& $nssm set $ServiceName AppRotateBytes 10485760
& $nssm set $ServiceName AppExit Default Restart
& $nssm set $ServiceName Start SERVICE_AUTO_START
& $nssm start $ServiceName
& $nssm status $ServiceName

Write-Host ""
Write-Host "Done. Params: $params"
Write-Host "Smoke test:  curl.exe http://$Addr/health-check   # -> OK"
Write-Host "Next: add the IIS /img rule + set IMAGE_RESIZER=imageproxy (see ..\DEPLOY.md)."
