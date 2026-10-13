#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: script/package_dmg.sh /path/to/Outpost.app [output.dmg]" >&2
  exit 64
fi

APP_PATH="$1"
OUTPUT_PATH="${2:-/private/tmp/Outpost.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 66
fi

hdiutil create \
  -volname "Outpost" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$OUTPUT_PATH"

echo "DMG created at $OUTPUT_PATH"
