#!/usr/bin/env bash
# Build the coffee-themed Espresso DMG. macOS only (needs hdiutil).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/Espresso.app}"
OUT="${2:-$ROOT/Espresso.dmg}"
HELPER_SRC="$ROOT/installer/brew-espresso.command"
BG="$ROOT/installer/dmg-background.png"
VOLICON="$ROOT/AppIcon.icns"
SETTINGS="$ROOT/installer/dmgbuild_settings.py"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "build-dmg.sh needs macOS (hdiutil / dmgbuild)." >&2
  exit 1
fi

[[ -d "$APP" ]] || { echo "Missing app bundle: $APP" >&2; exit 1; }
[[ -f "$HELPER_SRC" ]] || { echo "Missing helper: $HELPER_SRC" >&2; exit 1; }
[[ -f "$BG" ]] || { echo "Missing background: $BG" >&2; exit 1; }

if ! command -v dmgbuild >/dev/null 2>&1; then
  python3 -m pip install --user 'dmgbuild>=1.6.1'
  user_bin="$(python3 -c 'import site; print(site.USER_BASE)')/bin"
  export PATH="${user_bin}:$PATH"
fi
command -v dmgbuild >/dev/null 2>&1 || {
  echo "dmgbuild is not on PATH. Install with: python3 -m pip install dmgbuild" >&2
  exit 1
}

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/espresso-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/Espresso.app"
cp "$HELPER_SRC" "$STAGE/Brew Espresso.command"
chmod +x "$STAGE/Brew Espresso.command"

# Hide the .command extension so it reads as "Brew Espresso".
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a E "$STAGE/Brew Espresso.command" || true
fi

# Optional coffee-cup icon on the helper (best-effort).
ICON_PNG="$ROOT/installer/brew-helper-icon.png"
if [[ -f "$ICON_PNG" ]] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  ICONSET="$STAGE/brew.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$STAGE/brew-helper.icns" 2>/dev/null || true
  if [[ -f "$STAGE/brew-helper.icns" ]] && command -v fileicon >/dev/null 2>&1; then
    fileicon set "$STAGE/Brew Espresso.command" "$STAGE/brew-helper.icns" || true
  fi
fi

rm -f "$OUT"
dmgbuild \
  -s "$SETTINGS" \
  -D "app=$STAGE/Espresso.app" \
  -D "helper=$STAGE/Brew Espresso.command" \
  -D "background=$BG" \
  -D "volicon=$VOLICON" \
  -D "filename=$OUT" \
  "Espresso" \
  "$OUT"

echo "Built $OUT"
