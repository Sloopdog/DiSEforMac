#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/build/DiSE Programmer.app"
APP_ID="com.shaise.dise.macos"

# Quit any currently running copy so the next launch is the freshly built bundle.
osascript -e "tell application id \"$APP_ID\" to quit" >/dev/null 2>&1 || true
sleep 0.4

"$ROOT_DIR/build-macos-app.sh"
open -na "$APP_DIR"

echo "Relaunched: $APP_DIR"
