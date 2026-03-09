$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'
if (-not (Test-Path $dist)) {
    New-Item -ItemType Directory -Path $dist | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $dist ("LivingWorldNPCSP-$stamp.zip")

$items = @(
    Join-Path $root '42',
    Join-Path $root 'common',
    Join-Path $root 'AGENTS.md',
    Join-Path $root '.codex'
)

Compress-Archive -Path $items -DestinationPath $outFile -Force
Write-Host "Created $outFile" -ForegroundColor Green
