# Deploy Al-Ghaith Cloudflare Worker (OTP + image upload)
# Usage:
#   $env:CLOUDFLARE_API_TOKEN = "YOUR_TOKEN"
#   .\scripts\deploy-worker.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Read-DotEnvValue {
    param([string]$FilePath, [string]$Key)
    if (-not (Test-Path $FilePath)) { return $null }
    foreach ($line in Get-Content $FilePath) {
        if ($line -match "^\s*$Key\s*=\s*(.+)\s*$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

if (-not $env:CLOUDFLARE_API_TOKEN) {
    Write-Host "CLOUDFLARE_API_TOKEN is not set." -ForegroundColor Yellow
    Write-Host 'Set it: $env:CLOUDFLARE_API_TOKEN = "YOUR_TOKEN"' -ForegroundColor Gray
    exit 1
}

$envFile = Join-Path $Root "backend\.env"
$secrets = @{
    OTPIQ_API_KEY              = Read-DotEnvValue $envFile "OTPIQ_API_KEY"
    SESSION_SECRET             = Read-DotEnvValue $envFile "SESSION_SECRET"
    SUPABASE_URL               = Read-DotEnvValue $envFile "SUPABASE_URL"
    SUPABASE_SERVICE_ROLE_KEY  = Read-DotEnvValue $envFile "SUPABASE_SERVICE_ROLE_KEY"
}

$missing = @($secrets.Keys | Where-Object { [string]::IsNullOrWhiteSpace($secrets[$_]) })
if ($missing.Count -gt 0) {
    Write-Host "Missing in backend/.env: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "Deploying worker: lively-wind-9d98 ..." -ForegroundColor Green

$secretsFile = Join-Path $env:TEMP "alghaith-worker-secrets.json"
$secrets | ConvertTo-Json | Set-Content -Path $secretsFile -Encoding UTF8

try {
    Write-Host "Uploading worker secrets ..." -ForegroundColor DarkGray
    & npx.cmd --yes wrangler@latest secret bulk $secretsFile
    if ($LASTEXITCODE -ne 0) { throw "secret bulk failed ($LASTEXITCODE)" }

    Write-Host "Running wrangler deploy ..." -ForegroundColor Green
    & npx.cmd --yes wrangler@latest deploy
    if ($LASTEXITCODE -ne 0) { throw "deploy failed ($LASTEXITCODE)" }
}
finally {
    Remove-Item -Path $secretsFile -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. Worker URL:" -ForegroundColor Green
Write-Host "  https://lively-wind-9d98.alghaithapp.workers.dev" -ForegroundColor Cyan
