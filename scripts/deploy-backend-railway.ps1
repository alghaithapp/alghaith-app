# Deploy the Node.js API (backend/) to Railway production.
#
# Usage:
#   .\scripts\deploy-backend-railway.ps1
#
# Requires Railway CLI login and backend/ linked via:
#   .\scripts\link-backend-railway.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $Root "backend"
$ProductionUrl = "https://alghaith-app-production.up.railway.app"

function Test-RailwayLinked {
    param([string]$Directory)
    Push-Location $Directory
    try {
        $status = & railway status 2>&1 | Out-String
        return ($LASTEXITCODE -eq 0 -and $status -match "striking-fulfillment")
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-RailwayLinked $BackendDir)) {
    Write-Host "backend/ is not linked to striking-fulfillment." -ForegroundColor Yellow
    Write-Host "Run: .\scripts\link-backend-railway.ps1" -ForegroundColor Cyan
    exit 1
}

Write-Host "Deploying backend API to Railway..." -ForegroundColor Green
Write-Host "  Target: $ProductionUrl" -ForegroundColor DarkGray
Write-Host ""

Set-Location $BackendDir

# Upload the full repo archive; Railway service uses root directory `backend/`.
& railway up .. --path-as-root --detach
if ($LASTEXITCODE -ne 0) { throw "railway up failed ($LASTEXITCODE)" }

Write-Host ""
Write-Host "Deployment started. Check status:" -ForegroundColor Green
Write-Host "  cd backend; railway status" -ForegroundColor Cyan
Write-Host "  cd backend; railway logs --build" -ForegroundColor Cyan
Write-Host ""
Write-Host "After deploy finishes, verify:" -ForegroundColor Green
Write-Host "  $ProductionUrl/health" -ForegroundColor Cyan
Write-Host "  $ProductionUrl/app/home-categories" -ForegroundColor Cyan
