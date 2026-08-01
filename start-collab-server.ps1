$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js 22.5 or newer is required. Download it from https://nodejs.org/"
}

$nodeParts = (node --version).TrimStart('v').Split('.')
$major = [int]$nodeParts[0]
$minor = [int]$nodeParts[1]
if ($major -lt 22 -or ($major -eq 22 -and $minor -lt 5)) {
    throw "Node.js 22.5 or newer is required."
}

if (-not (Test-Path (Join-Path $projectRoot "node_modules\ws"))) {
    Write-Host "Installing collaboration server dependencies..." -ForegroundColor Yellow
    npm install
}

Write-Host "Starting DeltaMap collaboration server..." -ForegroundColor Green
npm start
