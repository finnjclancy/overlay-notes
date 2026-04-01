#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/Overlay Notes.app/Contents/MacOS/OverlayNotes"

"$ROOT_DIR/Scripts/build_app.sh"
pkill -f "$APP_BINARY" >/dev/null 2>&1 || true
open -n "$ROOT_DIR/dist/Overlay Notes.app"

printf 'Started Overlay Notes.\n'
