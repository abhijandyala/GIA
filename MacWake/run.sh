#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/abhijandyala/Downloads/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
export GIA_SIMULATOR_UDID="${GIA_SIMULATOR_UDID:-B8EBE242-5B9B-4AC1-A5AA-D98AC30C3FDF}"

SUPPORT="${HOME}/Library/Application Support/GIAMacWake"
mkdir -p "$SUPPORT"
cat > "$SUPPORT/env" <<EOF
DEVELOPER_DIR=${DEVELOPER_DIR}
GIA_SIMULATOR_UDID=${GIA_SIMULATOR_UDID}
EOF

echo "Building GIA Mac Wake..."
swift build -c release --package-path "$ROOT"

BIN="$ROOT/.build/release/GIAMacWake"
APP="${HOME}/Applications/GIAMacWake.app"
mkdir -p "${HOME}/Applications"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$BIN" "$APP/Contents/MacOS/GIAMacWake"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
xattr -cr "$APP"
find "$APP" \( -name '.DS_Store' -o -name '._*' \) -delete
codesign --force --sign - --entitlements "$ROOT/GIAMacWake.entitlements" "$APP/Contents/MacOS/GIAMacWake" >/dev/null
codesign --force --sign - --entitlements "$ROOT/GIAMacWake.entitlements" "$APP" >/dev/null || true

LOG="${HOME}/Library/Logs/GIAMacWake.log"
mkdir -p "$(dirname "$LOG")"
: >> "$LOG"

pkill -x GIAMacWake >/dev/null 2>&1 || true
sleep 0.3
/usr/bin/open -n "$APP" --env "DEVELOPER_DIR=${DEVELOPER_DIR}" --env "GIA_SIMULATOR_UDID=${GIA_SIMULATOR_UDID}"

echo "GIA Mac Wake is running in the background."
echo "Say Hey GIA. Keep Simulator open with GIA running."
echo "Log: ${LOG}"
echo "Stop with: pkill -x GIAMacWake"
