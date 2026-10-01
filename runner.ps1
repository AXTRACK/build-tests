$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$planPath = Join-Path $root 'test-plan.json'
$policyPath = Join-Path $root 'public-bundle-policy.json'

if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
    throw 'PUBLIC_TEST_PLAN_MISSING'
}
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw 'PUBLIC_TEST_POLICY_MISSING'
}

$plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20

if ([int]$plan.schemaVersion -lt 2) {
    throw "PUBLIC_TEST_PLAN_UNSUPPORTED: schemaVersion=$($plan.schemaVersion)"
}
$scopeId = [string]$plan.scopeId
$scopePolicyProperty = $policy.scopes.PSObject.Properties[$scopeId]
if ($null -eq $scopePolicyProperty) {
    throw "PUBLIC_TEST_SCOPE_NOT_ALLOWED: $scopeId"
}
$scopePolicy = $scopePolicyProperty.Value

if ([string]$plan.runner -ne [string]$scopePolicy.runner) {
    throw "PUBLIC_TEST_RUNNER_NOT_ALLOWED: $($plan.runner)"
}

function Test-PublicBundlePathMatch {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )

    $normalizedPath = $Path.Replace('\','/')
    $normalizedPattern = $Pattern.Replace('\','/')
    $placeholder = '__DOUBLE_STAR__'
    $escaped = [Regex]::Escape($normalizedPattern).Replace('\*\*',$placeholder).Replace('\*','[^/]*').Replace($placeholder,'.*')
    [Regex]::IsMatch($normalizedPath, ('^' + $escaped + '$'), [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

$declaredFiles = @($plan.files | ForEach-Object { ([string]$_).Replace('\','/') })
if ($declaredFiles.Count -eq 0) {
    throw 'PUBLIC_TEST_PLAN_FILES_MISSING'
}

$trackedFiles = @(& git -C $root ls-files)
if ($LASTEXITCODE -ne 0) {
    throw 'PUBLIC_TEST_TREE_ENUMERATION_FAILED'
}

$baselinePaths = @($policy.baselinePaths | ForEach-Object { [string]$_ })
$allowedPatterns = @($scopePolicy.allowedPaths | ForEach-Object { [string]$_ })

foreach ($pathValue in $trackedFiles) {
    $path = ([string]$pathValue).Replace('\','/')
    if ($baselinePaths -contains $path) { continue }

    $allowed = $false
    foreach ($pattern in $allowedPatterns) {
        if (Test-PublicBundlePathMatch -Path $path -Pattern $pattern) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) {
        throw "PUBLIC_TEST_BUNDLE_PATH_NOT_ALLOWED: $path"
    }
    if ($declaredFiles -notcontains $path) {
        throw "PUBLIC_TEST_BUNDLE_UNDECLARED_FILE: $path"
    }
}

foreach ($declaredPath in $declaredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $declaredPath) -PathType Leaf)) {
        throw "PUBLIC_TEST_BUNDLE_DECLARED_FILE_MISSING: $declaredPath"
    }

    $allowed = $false
    foreach ($pattern in $allowedPatterns) {
        if (Test-PublicBundlePathMatch -Path $declaredPath -Pattern $pattern) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) {
        throw "PUBLIC_TEST_PLAN_FILE_NOT_ALLOWED: $declaredPath"
    }
}

$runner = Join-Path $root ([string]$plan.runner)
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "PUBLIC_TEST_RUNNER_MISSING: $($plan.runner)"
}

Write-Host ("Scope: {0}" -f $scopeId)
Write-Host ("Source: {0}" -f $plan.sourceSha)
Write-Host ("Bundle: {0}" -f $plan.bundleDigest)
Write-Host ("Files: {0}" -f $declaredFiles.Count)
& pwsh -NoProfile -File $runner
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Public test scope PASS.' -ForegroundColor Green
