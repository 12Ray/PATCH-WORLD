param(
    [switch]$ReportOnly,
    [switch]$StrictReport,
    [switch]$TellsApproved,
    [string]$Since
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$releaseExe = Join-Path $repositoryRoot 'build\windows\x64\runner\Release\patch_world.exe'
$reportScript = Join-Path $PSScriptRoot 'survival_playtest_report.py'

if (-not $ReportOnly) {
    if (-not (Test-Path -LiteralPath $releaseExe -PathType Leaf)) {
        throw "Windows release executable not found. Run 'flutter build windows --release' first: $releaseExe"
    }

    Write-Host 'Starting the normal PATCHWORLD Windows release.'
    Write-Host 'Complete or fail each PATCH//SURVIVE run so its result is persisted.'
    Start-Process -FilePath $releaseExe -WorkingDirectory (Split-Path -Parent $releaseExe) -Wait
}

$reportArguments = @($reportScript)
if ($StrictReport) { $reportArguments += '--strict' }
if ($TellsApproved) { $reportArguments += '--tells-approved' }
if ($Since) { $reportArguments += @('--since', $Since) }

$pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pythonLauncher) {
    & $pythonLauncher.Source -3 @reportArguments
    exit $LASTEXITCODE
}

$pythonLauncher = Get-Command python -ErrorAction SilentlyContinue
if ($pythonLauncher) {
    & $pythonLauncher.Source @reportArguments
    exit $LASTEXITCODE
}

throw 'Python 3 was not found. Run tool\survival_playtest_report.py with any Python 3 installation.'
