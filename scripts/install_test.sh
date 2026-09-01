#!/usr/bin/env bash
# Tests for scripts/install.sh that run on Linux and macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
HELPER="$ROOT/installer/brew-espresso.command"
BUILD_DMG="$ROOT/installer/build-dmg.sh"
failures=0

assert() {
  local name="$1"
  if eval "$2"; then
    printf 'ok  %s\n' "$name"
  else
    printf 'not ok  %s\n' "$name"
    failures=$((failures + 1))
  fi
}

echo "== syntax"
bash -n "$INSTALL"
bash -n "$HELPER"
bash -n "$BUILD_DMG"
echo "ok  bash -n"

echo "== install.sh --self-test"
bash "$INSTALL" --self-test

echo "== sourced helpers"
# shellcheck disable=SC1090
source "$INSTALL"
assert "is_macos matches uname" \
  '[[ "$(uname -s)" == Darwin ]] && espresso_is_macos || { [[ "$(uname -s)" != Darwin ]] && ! espresso_is_macos; }'

espresso_dmg_url=""
espresso_repo="eng-kitchen/espresso"
assert "default latest url" \
  '[[ "$(espresso_dmg_url_for "")" == "https://github.com/eng-kitchen/espresso/releases/latest/download/Espresso.dmg" ]]'

echo "== helper script"
assert "helper is a bash script" \
  'head -n1 "$HELPER" | grep -q bash'
assert "helper targets ~/Applications" \
  'grep -q "HOME}/Applications" "$HELPER"'
assert "helper clears quarantine" \
  'grep -q "com.apple.quarantine" "$HELPER"'
assert "helper ad-hoc signs" \
  'grep -q "codesign --sign -" "$HELPER"'
assert "helper launches the app" \
  'grep -q "open \"\$DEST\"" "$HELPER"'

echo "== install.sh Gatekeeper path"
assert "install.sh clears quarantine" \
  'grep -q "com.apple.quarantine" "$INSTALL"'
assert "install.sh ad-hoc signs" \
  'grep -q "codesign --sign -" "$INSTALL"'
assert "install.sh refuses non-macOS" \
  'grep -q "only runs on a Mac" "$INSTALL"'

echo "== dmg packaging"
assert "background exists" '[[ -f "$ROOT/installer/dmg-background.png" ]]'
assert "helper icon exists" '[[ -f "$ROOT/installer/brew-helper-icon.png" ]]'
assert "dmgbuild settings exist" '[[ -f "$ROOT/installer/dmgbuild_settings.py" ]]'
assert "build-dmg refuses Linux" 'grep -q "needs macOS" "$BUILD_DMG"'

if [[ "$(uname -s)" != Darwin ]]; then
  echo "== build-dmg.sh on Linux"
  if "$BUILD_DMG" >/tmp/espresso-dmg-err.txt 2>&1; then
    printf 'not ok  build-dmg should fail on Linux\n'
    failures=$((failures + 1))
  else
    printf 'ok  build-dmg fails on Linux\n'
  fi
fi

echo "== landing page"
PAGE="$ROOT/docs/index.html"
assert "keeps VERSION placeholder" 'grep -q "{{VERSION}}" "$PAGE"'
assert "offers curl brew command" 'grep -q "install.sh | bash" "$PAGE"'
assert "still offers DMG download" 'grep -q "Espresso.dmg" "$PAGE"'
assert "explains Gatekeeper" 'grep -qi "Gatekeeper" "$PAGE"'

if [[ "$failures" -eq 0 ]]; then
  echo
  echo "all installer tests passed"
  exit 0
fi
echo
echo "$failures installer test(s) failed"
exit 1
