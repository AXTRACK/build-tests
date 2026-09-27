$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$subject = Join-Path $PSScriptRoot 'subject'
Set-Location -LiteralPath $subject

Write-Host 'Node:' (node --version)
Write-Host 'npm:' (npm --version)

npm install --package-lock-only --ignore-scripts --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npm ci --ignore-scripts --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npm run typecheck
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npm run build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npm test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'NAS ChatGPT MCP baseline PASS.' -ForegroundColor Green
