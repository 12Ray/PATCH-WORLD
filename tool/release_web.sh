#!/usr/bin/env bash
set -euo pipefail
VERSION="${1:-0.1.0}"
SHA="$(git rev-parse --short HEAD)"
BUILD_TIME="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean."
  exit 1
fi
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --release \
  --dart-define=APP_VERSION="$VERSION" \
  --dart-define=BUILD_SHA="$SHA" \
  --dart-define=BUILD_TIME="$BUILD_TIME"
mkdir -p releases
(cd build/web && zip -r "../../releases/patch-world-$VERSION-$SHA.zip" .)
echo "Built PATCH//WORLD $VERSION ($SHA) at $BUILD_TIME"
