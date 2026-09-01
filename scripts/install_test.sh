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

echo "== EXIT trap must not leak unbound mount"
assert "cleanup helper exists" 'type espresso_cleanup >/dev/null'
assert "trap calls espresso_cleanup" 'grep -q "trap espresso_cleanup EXIT" "$INSTALL"'
assert "trap does not expand local mount" '! grep -q "detach -quiet \"\$mount\"" "$INSTALL"'

cleanup_err="$(
  set +e
  (
    set -euo pipefail
    espresso_tmp=""
    espresso_mount=""
    espresso_cleanup
    printf 'survived\n'
  ) 2>&1
  printf 'exit:%s\n' "$?"
)"
assert "cleanup under nounset survives" '[[ "$cleanup_err" == *survived* && "$cleanup_err" != *unbound* ]]'

# Function-return + EXIT trap + nounset: the exact failure Yuri hit.
trap_out="$(bash -c '
set -euo pipefail
# shellcheck source=/dev/null
source "$1"
espresso_tmp=""
espresso_mount=""
simulate() {
  trap espresso_cleanup EXIT
  espresso_cleanup
  trap - EXIT
}
simulate
echo survived
' _ "$INSTALL" 2>&1)" || true
assert "success path does not print unbound variable" \
  '[[ "$trap_out" == *survived* && "$trap_out" != *unbound* ]]'


echo "== dmg packaging"
assert "background exists" '[[ -f "$ROOT/installer/dmg-background.png" ]]'
assert "helper icon exists" '[[ -f "$ROOT/installer/brew-helper-icon.png" ]]'
assert "dmgbuild settings exist" '[[ -f "$ROOT/installer/dmgbuild_settings.py" ]]'
assert "build-dmg refuses Linux" 'grep -q "needs macOS" "$BUILD_DMG"'
assert "build-dmg uses a venv for dmgbuild" 'grep -q "python3 -m venv" "$BUILD_DMG"'

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
assert "does not offer a DMG download" '! grep -q "Download Espresso.dmg" "$PAGE"'
assert "does not document a manual DMG path" '! grep -qi "Café tray" "$PAGE"'
assert "explains Gatekeeper" 'grep -qi "Gatekeeper" "$PAGE"'

if [[ "$failures" -eq 0 ]]; then
  echo
  echo "all installer tests passed"
  exit 0
fi
echo
echo "$failures installer test(s) failed"
exit 1
