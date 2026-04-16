#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/build/ClickRipples.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
MODULE_CACHE_DIR="$ROOT_DIR/build/module-cache"
SIGN_IDENTITY="${CLICKRIPPLES_SIGN_IDENTITY:--}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

swiftc \
  -O \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework Cocoa \
  "$ROOT_DIR/Sources/main.swift" \
  -o "$MACOS_DIR/ClickRipples"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R "$ROOT_DIR/Resources/." "$RESOURCES_DIR"

codesign \
  --force \
  --deep \
  --sign "$SIGN_IDENTITY" \
  --timestamp=none \
  "$APP_DIR"

echo "Built $APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
