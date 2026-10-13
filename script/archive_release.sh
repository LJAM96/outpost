#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-/private/tmp/Outpost.xcarchive}"

xcodebuild \
  -project "$ROOT_DIR/Outpost.xcodeproj" \
  -scheme Outpost \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "Archive created at $ARCHIVE_PATH"
