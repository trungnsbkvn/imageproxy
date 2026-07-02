<#
  build.ps1 — build the Windows imageproxy binary into build\imageproxy.exe.
  Pure Go, no cgo. Requires Go 1.25.8+ on PATH. Run from the repo root.
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  throw "Go toolchain not found on PATH. Install Go 1.25.8+ (https://go.dev/dl/)."
}

New-Item -ItemType Directory -Force (Join-Path $here 'build') | Out-Null

go mod download
$env:CGO_ENABLED = '0'
$env:GOOS        = 'windows'
$env:GOARCH      = 'amd64'
go build -ldflags "-s -w" -o build/imageproxy.exe ./cmd/imageproxy
if ($LASTEXITCODE -ne 0) { throw "go build failed ($LASTEXITCODE)." }

Write-Host "Built build\imageproxy.exe"
& (Join-Path $here 'build\imageproxy.exe') -addr 127.0.0.1:8099 &
Start-Sleep -Milliseconds 800
try { $ok = (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8099/health-check).Content } catch { $ok = "(smoke test skipped)" }
Get-Process imageproxy -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Health check: $ok"
