param(
    [Parameter(Mandatory)][string]$EventPath,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$event = Get-Content -LiteralPath $EventPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
$policy = Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20

if ([int]$policy.schemaVersion -ne 1) {
    throw "BUILD_TEST_POLICY_SCHEMA_UNSUPPORTED: $($policy.schemaVersion)"
}

$actor = [string]$event.sender.login
if (@($policy.allowedActors) -notcontains $actor) {
    throw "BUILD_TEST_ACTOR_NOT_ALLOWED: $actor"
}

$title = [string]$event.issue.title
$prefix = [string]$policy.requestTitlePrefix
if (-not $title.StartsWith($prefix, [StringComparison]::Ordinal)) {
    throw "BUILD_TEST_TITLE_INVALID: expected prefix '$prefix'"
}

$body = [string]$event.issue.body
$values = @{}
foreach ($line in ($body -split "`r?`n")) {
    if ($line -match '^([a-z_]+):\s*(.+?)\s*$') {
        $values[$matches[1]] = $matches[2]
    }
}

foreach ($required in @('source_repository','source_sha','profile')) {
    if (-not $values.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$values[$required])) {
        throw "BUILD_TEST_REQUEST_FIELD_MISSING: $required"
    }
}

$sourceRepository = [string]$values.source_repository
$sourceSha = [string]$values.source_sha
$profileName = [string]$values.profile

if ($sourceSha -notmatch '^[0-9a-fA-F]{40}$') {
    throw "BUILD_TEST_SOURCE_SHA_INVALID: $sourceSha"
}

$repoProperty = $policy.profiles.PSObject.Properties[$sourceRepository]
if ($null -eq $repoProperty) {
    throw "BUILD_TEST_SOURCE_REPOSITORY_NOT_ALLOWED: $sourceRepository"
}

$profileProperty = $repoProperty.Value.PSObject.Properties[$profileName]
if ($null -eq $profileProperty) {
    throw "BUILD_TEST_PROFILE_NOT_ALLOWED: $sourceRepository/$profileName"
}

$profile = $profileProperty.Value
$runner = [string]$profile.runner
$nodeVersion = [string]$profile.nodeVersion

if ([string]::IsNullOrWhiteSpace($runner) -or $runner.Contains('..') -or [IO.Path]::IsPathRooted($runner)) {
    throw "BUILD_TEST_RUNNER_INVALID: $runner"
}
if ($nodeVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "BUILD_TEST_NODE_VERSION_INVALID: $nodeVersion"
}

@(
    "source_repository=$sourceRepository"
    "source_sha=$sourceSha"
    "profile=$profileName"
    "runner=$runner"
    "node_version=$nodeVersion"
) | Add-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Resolved $sourceRepository@$sourceSha profile=$profileName runner=$runner"
