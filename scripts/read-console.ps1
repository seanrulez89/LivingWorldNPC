$ErrorActionPreference = 'Stop'

$zomboid = Join-Path $env:USERPROFILE 'Zomboid'
$console = Join-Path $zomboid 'console.txt'

if (-not (Test-Path $console)) {
    Write-Host "console.txt not found at: $console" -ForegroundColor Yellow
    exit 1
}

Get-Content $console -Tail 200
