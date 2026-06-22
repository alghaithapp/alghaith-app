# configure_fcm_railway.ps1
# Al-Ghaith App — Configure Firebase FCM Service Account for Railway
# ===================================================================
# This script reads a Firebase service account JSON file and helps you
# set the FIREBASE_SERVICE_ACCOUNT_JSON environment variable on Railway
# (or in a local .env file for development).
#
# Usage:
#   .\scripts\configure_fcm_railway.ps1
#
# Prerequisites:
#   - Railway CLI installed and authenticated (railway login)
#   - OR a local .env file in backend/.env

$ErrorActionPreference = 'Stop'

function ValidateServiceAccount($jsonPath) {
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        Write-Host "ERROR: File not found: $jsonPath" -ForegroundColor Red
        return $null
    }

    try {
        $raw = Get-Content -Raw -LiteralPath $jsonPath
        $parsed = $raw | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: Invalid JSON in $jsonPath — $_" -ForegroundColor Red
        return $null
    }

    $required = @('project_id', 'client_email', 'private_key')
    $missing = @()
    foreach ($field in $required) {
        $value = $parsed.$field
        if (-not $value -or $value -eq '') {
            $missing += $field
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "ERROR: Missing required field(s): $($missing -join ', ')" -ForegroundColor Red
        return $null
    }

    $project = $parsed.project_id
    $email = $parsed.client_email
    $keyPreview = $parsed.private_key.Substring(0, [Math]::Min(40, $parsed.private_key.Length)) + '...'

    Write-Host "`n✅ Service account JSON is valid:" -ForegroundColor Green
    Write-Host "   Project ID:    $project"
    Write-Host "   Client Email:  $email"
    Write-Host "   Private Key:   $keyPreview"

    return $raw
}

function WriteRailwayCliCommand($rawJson) {
    $escaped = $rawJson -replace "'", "'\\''"
    Write-Host "`n📦 Railway CLI command (run this in your terminal):" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "railway variables set FIREBASE_SERVICE_ACCOUNT_JSON='$escaped'" -ForegroundColor White
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "`nOr set it via Railway Dashboard → Variables → FIREBASE_SERVICE_ACCOUNT_JSON" -ForegroundColor Yellow
    Write-Host "   Paste the full JSON as the value (with quotes)." -ForegroundColor Yellow
}

function WriteDotEnvEntry($rawJson) {
    $escaped = $rawJson -replace '"', '""'
    Write-Host "`n📝 .env entry for local development (append to backend/.env):" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "FIREBASE_SERVICE_ACCOUNT_JSON=$escaped" -ForegroundColor White
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
}

function WriteRailwayJsonFile($rawJson, $jsonPath) {
    $targetDir = "$PSScriptRoot\..\backend"
    $targetFile = "$targetDir\firebase-service-account.json"

    if (-not (Test-Path -LiteralPath $targetDir)) {
        Write-Host "ERROR: Directory $targetDir not found" -ForegroundColor Red
        return
    }

    $rawJson | Out-File -FilePath $targetFile -Encoding utf8
    Write-Host "`n📄 Copied to $targetFile" -ForegroundColor Green
    Write-Host "   Then run: railway variables set FIREBASE_SERVICE_ACCOUNT_JSON=@firebase-service-account.json" -ForegroundColor Cyan
}

# --- Main ---
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Al-Ghaith App — Firebase FCM Railway Configuration" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$jsonPath = Read-Host "Enter the path to your Firebase service account JSON file"
$jsonPath = $jsonPath.Trim('"').Trim("'")

$rawJson = ValidateServiceAccount $jsonPath
if (-not $rawJson) {
    exit 1
}

Write-Host ""
Write-Host "Choose an action:" -ForegroundColor Yellow
Write-Host "  1) Generate Railway CLI command (railway variables set ...)"
Write-Host "  2) Generate .env entry for local testing"
Write-Host "  3) Copy service account to backend/firebase-service-account.json (for railway variables @file syntax)"
Write-Host "  4) All of the above"
$choice = Read-Host "Enter choice (1-4)"

switch ($choice) {
    '1' { WriteRailwayCliCommand $rawJson }
    '2' { WriteDotEnvEntry $rawJson }
    '3' { WriteRailwayJsonFile $rawJson $jsonPath }
    '4' {
        WriteRailwayCliCommand $rawJson
        WriteDotEnvEntry $rawJson
        WriteRailwayJsonFile $rawJson $jsonPath
    }
    default {
        Write-Host "Invalid choice, defaulting to all." -ForegroundColor Red
        WriteRailwayCliCommand $rawJson
        WriteDotEnvEntry $rawJson
        WriteRailwayJsonFile $rawJson $jsonPath
    }
}

Write-Host "`nDone." -ForegroundColor Green
