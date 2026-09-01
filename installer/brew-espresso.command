#!/bin/bash
# Brew Espresso — one-click install from the disk image.
# Copies Espresso.app to ~/Applications, ad-hoc signs it, clears
# Gatekeeper's quarantine flag, and launches. No Apple Developer ID.

set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
SRC="${SELF}/Espresso.app"
DEST_DIR="${HOME}/Applications"
DEST="${DEST_DIR}/Espresso.app"

amber=$'\033[38;5;214m'
cream=$'\033[38;5;223m'
green=$'\033[38;5;114m'
red=$'\033[38;5;167m'
dim=$'\033[38;5;94m'
off=$'\033[0m'

die() {
  printf '%s✘%s %s%s%s\n' "$red" "$off" "$cream" "$*" "$off" >&2
  printf '\nPress Return to close this window.\n'
  read -r _
  exit 1
}

step() { printf '  %s%s%s  %s%s%s\n' "$amber" "$1" "$off" "$cream" "$2" "$off"; }
ok()   { printf '  %s✔%s  %s%s%s\n' "$green" "$off" "$cream" "$*" "$off"; }

cat <<EOF

      )  (
     (   ) )
      ) ( (
    _______)_
   |         |]   Brew Espresso
   \         /    Skip the Gatekeeper lecture.
    \`-------'

EOF

[[ -d "$SRC" ]] || die "Espresso.app was not next to this script. Keep this disk image mounted and try again."

step "☕" "Pouring into ${DEST_DIR}…"
pkill -x espresso 2>/dev/null || true
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
ditto "$SRC" "$DEST" || die "Could not copy Espresso.app"

step "♨" "Steaming (signing, clearing quarantine)…"
codesign --sign - --force --deep "$DEST" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
xattr -cr "$DEST" 2>/dev/null || true
ok "No quarantine. No lecture."

step "☕" "First sip…"
open "$DEST"
ok "Espresso is on the bar — look at the menu bar"

printf '\n  %sStay caffeinated.%s\n' "$dim" "$off"
printf '\nPress Return to close this window.\n'
read -r _
