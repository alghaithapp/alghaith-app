# Link the local backend folder to the production Railway API project.
# Run once per machine (or after `railway unlink` in backend/).
#
# Usage:
#   .\scripts\link-backend-railway.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $Root "backend"

$ProjectId = "9e9359a6-21ba-407f-8190-68581ad425c6" # striking-fulfillment
$ServiceName = "alghaith-app"
$Environment = "production"
$ProductionUrl = "https://alghaith-app-production.up.railway.app"

Write-Host "Linking backend/ to Railway production API..." -ForegroundColor Green
Write-Host "  Project: striking-fulfillment ($ProjectId)" -ForegroundColor DarkGray
Write-Host "  Service: $ServiceName" -ForegroundColor DarkGray
Write-Host "  URL:     $ProductionUrl" -ForegroundColor DarkGray
Write-Host ""

Set-Location $BackendDir

$rootStatus = & railway status 2>&1
if ($LASTEXITCODE -eq 0 -and ($rootStatus -match "Project:")) {
    Write-Host "Root folder is still linked to Railway. Unlinking it first..." -ForegroundColor Yellow
    Set-Location $Root
    & railway unlink -y
    if ($LASTEXITCODE -ne 0) { throw "Failed to unlink Railway project from repo root." }
    Set-Location $BackendDir
}

& railway link -p $ProjectId -e $Environment -s $ServiceName
if ($LASTEXITCODE -ne 0) { throw "railway link failed ($LASTEXITCODE)" }

Write-Host ""
Write-Host "Done. Verify with:" -ForegroundColor Green
Write-Host "  cd backend" -ForegroundColor Cyan
Write-Host "  railway status" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deploy with:" -ForegroundColor Green
Write-Host "  .\scripts\deploy-backend-railway.ps1" -ForegroundColor Cyan
