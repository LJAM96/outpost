#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-/private/tmp/outpost-derived}"

xcodebuild \
  -project "$ROOT_DIR/Outpost.xcodeproj" \
  -scheme Outpost \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  test

