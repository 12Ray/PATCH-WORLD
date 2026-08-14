$ErrorActionPreference = "Stop"
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart format --output=none --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$PSScriptRoot/qa_budget.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output "PATCH//WORLD checks passed."
