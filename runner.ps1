$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$planPath = Join-Path $root 'test-plan.json'
if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
    throw 'PUBLIC_TEST_PLAN_MISSING'
}
$plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
$runner = Join-Path $root ([string]$plan.runner)
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "PUBLIC_TEST_RUNNER_MISSING: $($plan.runner)"
}
Write-Host ("Scope: {0}" -f $plan.scopeId)
Write-Host ("Source: {0}" -f $plan.sourceSha)
Write-Host ("Bundle: {0}" -f $plan.bundleDigest)
& pwsh -NoProfile -File $runner
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Public test scope PASS.' -ForegroundColor Green
