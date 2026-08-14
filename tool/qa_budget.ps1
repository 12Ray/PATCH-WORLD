param(
    [string]$WebRoot = "build/web",
    [int64]$MaxWebBytes = 90MB,
    [int64]$MaxFlutterAssetBytes = 45MB,
    [int64]$MaxGameAssetBytes = 42MB,
    [int64]$MaxMainDartJsBytes = 4MB,
    [int64]$MaxSingleGameAssetBytes = 3MB
)

$ErrorActionPreference = "Stop"
$resolvedWebRoot = Resolve-Path -LiteralPath $WebRoot
$flutterAssetsRoot = Join-Path $resolvedWebRoot "assets"
$gameAssetsRoot = Join-Path $flutterAssetsRoot "assets"
$mainDartJsPath = Join-Path $resolvedWebRoot "main.dart.js"

if (-not (Test-Path -LiteralPath $flutterAssetsRoot -PathType Container)) {
    throw "Flutter asset directory not found: $flutterAssetsRoot"
}
if (-not (Test-Path -LiteralPath $gameAssetsRoot -PathType Container)) {
    throw "Game asset directory not found: $gameAssetsRoot"
}
if (-not (Test-Path -LiteralPath $mainDartJsPath -PathType Leaf)) {
    throw "Compiled application not found: $mainDartJsPath"
}

function Get-FileBytes {
    param([string]$Path)
    $measurement = Get-ChildItem -LiteralPath $Path -File -Recurse |
        Measure-Object -Property Length -Sum
    if ($null -eq $measurement.Sum) { return [int64]0 }
    return [int64]$measurement.Sum
}

function Format-Mebibytes {
    param([int64]$Bytes)
    return "{0:N2} MiB" -f ($Bytes / 1MB)
}

$gameAssetFiles = Get-ChildItem -LiteralPath $gameAssetsRoot -File -Recurse
$largestGameAsset = $gameAssetFiles | Sort-Object -Property Length -Descending |
    Select-Object -First 1

$metrics = @(
    [pscustomobject]@{
        Metric = "Complete web output"
        Actual = Get-FileBytes -Path $resolvedWebRoot
        Limit = $MaxWebBytes
        Detail = $resolvedWebRoot.Path
    },
    [pscustomobject]@{
        Metric = "Flutter asset payload"
        Actual = Get-FileBytes -Path $flutterAssetsRoot
        Limit = $MaxFlutterAssetBytes
        Detail = $flutterAssetsRoot
    },
    [pscustomobject]@{
        Metric = "PATCH//WORLD game assets"
        Actual = Get-FileBytes -Path $gameAssetsRoot
        Limit = $MaxGameAssetBytes
        Detail = $gameAssetsRoot
    },
    [pscustomobject]@{
        Metric = "main.dart.js"
        Actual = [int64](Get-Item -LiteralPath $mainDartJsPath).Length
        Limit = $MaxMainDartJsBytes
        Detail = $mainDartJsPath
    },
    [pscustomobject]@{
        Metric = "Largest game asset"
        Actual = [int64]$largestGameAsset.Length
        Limit = $MaxSingleGameAssetBytes
        Detail = $largestGameAsset.FullName
    }
)

$failed = $false
foreach ($metric in $metrics) {
    $status = if ($metric.Actual -le $metric.Limit) { "PASS" } else { "FAIL" }
    if ($status -eq "FAIL") { $failed = $true }
    Write-Output (
        "[{0}] {1}: {2} / {3}" -f `
            $status,
            $metric.Metric,
            (Format-Mebibytes -Bytes $metric.Actual),
            (Format-Mebibytes -Bytes $metric.Limit)
    )
    Write-Output ("       {0}" -f $metric.Detail)
}

if ($failed) {
    throw "Web release QA budget exceeded. Review docs/RELEASE_QA_BUDGETS.md."
}

Write-Output "PATCH//WORLD web release QA budgets passed."
