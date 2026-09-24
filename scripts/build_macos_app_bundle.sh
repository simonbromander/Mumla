#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
PRODUCT="mumla-mac"
APP_NAME="Mumla"
APP_DIR="$ROOT/.build/$CONFIGURATION/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

swift build -c "$CONFIGURATION" --product "$PRODUCT"

if [[ -d "$APP_DIR" ]]; then
  BACKUP="$APP_DIR.previous.$$"
  mv "$APP_DIR" "$BACKUP"
fi

mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/$CONFIGURATION/$PRODUCT" "$MACOS/$APP_NAME"
cp "$ROOT/Packaging/macOS/Info.plist" "$CONTENTS/Info.plist"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

if [[ -n "${BACKUP:-}" && -d "$BACKUP" ]]; then
  rm -rf "$BACKUP"
fi

echo "$APP_DIR"
