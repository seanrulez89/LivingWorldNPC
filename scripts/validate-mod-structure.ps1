$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$required = @(
    '42',
    '42/mod.info',
    '42/media',
    '42/media/lua',
    'common',
    'AGENTS.md',
    '.codex/config.toml'
)

$missing = @()
foreach ($item in $required) {
    $path = Join-Path $root $item
    if (-not (Test-Path $path)) {
        $missing += $item
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Missing required paths:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Build 42 local mod structure looks valid." -ForegroundColor Green
