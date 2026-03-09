$ErrorActionPreference = 'Stop'

$target = Join-Path $env:USERPROFILE 'Zomboid\Saves'
if (-not (Test-Path $target)) {
    Write-Host "Save directory not found: $target" -ForegroundColor Yellow
    exit 1
}

Write-Host "This script is intentionally conservative." -ForegroundColor Yellow
Write-Host "Search your save files and mod data for keys related to LivingWorldNPCSP / LWN_SP before deleting anything." -ForegroundColor Yellow
Write-Host "Target root: $target"
