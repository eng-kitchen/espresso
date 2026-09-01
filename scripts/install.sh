#!/usr/bin/env bash
# Espresso installer — brew a cup, skip the Gatekeeper lecture.
# Usage:
#   curl -fsSL https://eng-kitchen.github.io/espresso/install.sh | bash
#   ESPRESSO_VERSION=0.1.5 bash install.sh
#   bash install.sh --help

espresso_repo="${ESPRESSO_REPO:-eng-kitchen/espresso}"
espresso_install_dir="${ESPRESSO_INSTALL_DIR:-$HOME/Applications}"
espresso_dmg_url="${ESPRESSO_DMG_URL:-}"
espresso_version="${ESPRESSO_VERSION:-}"
espresso_launch="${ESPRESSO_LAUNCH:-1}"

espresso_is_macos() {
  [[ "$(uname -s)" == Darwin ]]
}

espresso_latest_tag() {
  curl -fsSL "https://api.github.com/repos/${espresso_repo}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' \
    | head -n1
}

espresso_dmg_url_for() {
  local tag="$1"
  if [[ -n "$espresso_dmg_url" ]]; then
    printf '%s\n' "$espresso_dmg_url"
    return
  fi
  if [[ -n "$tag" ]]; then
    printf 'https://github.com/%s/releases/download/%s/Espresso.dmg\n' "$espresso_repo" "$tag"
  else
    printf 'https://github.com/%s/releases/latest/download/Espresso.dmg\n' "$espresso_repo"
  fi
}

espresso_use_color() {
  [[ -t 1 && -z "${NO_COLOR:-}" ]]
}

espresso_c() {
  # espresso_c <color> <text>
  if espresso_use_color; then
    local code=""
    case "$1" in
      amber) code='38;5;214' ;;
      cream) code='38;5;223' ;;
      dim)   code='38;5;94' ;;
      green) code='38;5;114' ;;
      red)   code='38;5;167' ;;
      *)     code='0' ;;
    esac
    shift
    printf '\033[%sm%s\033[0m' "$code" "$*"
  else
    shift
    printf '%s' "$*"
  fi
}

espresso_banner() {
  cat <<'EOF'

      )  (
     (   ) )
      ) ( (
    _______)_
   |         |]   Espresso
   \         /    Keep your Mac awake.
    `-------'

EOF
}

espresso_die() {
  printf '%s %s\n' "$(espresso_c red '✘')" "$(espresso_c cream "$*")" >&2
  exit 1
}

espresso_step() {
  printf '  %s  %s\n' "$(espresso_c amber "$1")" "$(espresso_c cream "$2")"
}

espresso_ok() {
  printf '  %s  %s\n' "$(espresso_c green '✔')" "$(espresso_c cream "$*")"
}

espresso_help() {
  cat <<EOF
Brew Espresso — unsigned-friendly Mac installer

Usage:
  curl -fsSL https://eng-kitchen.github.io/espresso/install.sh | bash
  bash install.sh [--version vX.Y.Z] [--no-launch]

Installs Espresso.app to ${espresso_install_dir}, ad-hoc signs it,
clears the Gatekeeper quarantine flag, and launches it.

This exists because Espresso is not notarized (no paid Apple Developer
ID). Downloading the DMG in a browser and double-clicking the app is
what trips Gatekeeper. Brewing from Terminal skips that dance.

Environment:
  ESPRESSO_VERSION      Release tag (e.g. v0.1.5). Default: latest
  ESPRESSO_INSTALL_DIR  Destination. Default: ~/Applications
  ESPRESSO_DMG_URL      Override the download URL
  ESPRESSO_REPO         GitHub owner/repo. Default: ${espresso_repo}
  ESPRESSO_LAUNCH       Set to 0 to skip launching
  NO_COLOR              Disable ANSI colors
EOF
}

espresso_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        espresso_help
        exit 0
        ;;
      --version)
        [[ $# -ge 2 ]] || espresso_die "--version needs a tag like v0.1.5"
        espresso_version="$2"
        shift 2
        ;;
      --no-launch)
        espresso_launch=0
        shift
        ;;
      --self-test)
        espresso_self_test
        exit $?
        ;;
      *)
        espresso_die "Unknown option: $1  (try --help)"
        ;;
    esac
  done
}

espresso_self_test() {
  local failures=0
  assert() {
    local name="$1" left="$2" right="$3"
    if [[ "$left" == "$right" ]]; then
      printf 'ok  %s\n' "$name"
    else
      printf 'not ok  %s\n  got:  %s\n  want: %s\n' "$name" "$left" "$right"
      failures=$((failures + 1))
    fi
  }

  espresso_dmg_url=""
  espresso_repo="eng-kitchen/espresso"
  assert "latest dmg url" \
    "$(espresso_dmg_url_for "")" \
    "https://github.com/eng-kitchen/espresso/releases/latest/download/Espresso.dmg"

  assert "versioned dmg url" \
    "$(espresso_dmg_url_for "v0.1.5")" \
    "https://github.com/eng-kitchen/espresso/releases/download/v0.1.5/Espresso.dmg"

  espresso_dmg_url="https://example.test/Espresso.dmg"
  assert "explicit dmg url wins" \
    "$(espresso_dmg_url_for "v9.9.9")" \
    "https://example.test/Espresso.dmg"

  if espresso_is_macos; then
    printf 'ok  macos detected\n'
  else
    printf 'ok  non-macos detected (%s)\n' "$(uname -s)"
  fi

  if [[ "$failures" -eq 0 ]]; then
    printf 'all tests passed\n'
    return 0
  fi
  printf '%s test(s) failed\n' "$failures"
  return 1
}

espresso_quit_running() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -x espresso 2>/dev/null || true
  fi
}

espresso_trust() {
  local bundle="$1"
  if command -v codesign >/dev/null 2>&1; then
    codesign --sign - --force --deep "$bundle" >/dev/null 2>&1 || true
  fi
  if command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$bundle" 2>/dev/null || true
    xattr -cr "$bundle" 2>/dev/null || true
  fi
}

# Not local: the EXIT trap must still see these after espresso_install returns.
# Bash 3.2 (macOS /bin/bash) expands trap strings after locals are torn down,
# which produced `mount: unbound variable` on a successful brew.
espresso_tmp=""
espresso_mount=""

espresso_cleanup() {
  if [[ -n "${espresso_mount:-}" ]]; then
    hdiutil detach -quiet "$espresso_mount" 2>/dev/null || true
    espresso_mount=""
  fi
  if [[ -n "${espresso_tmp:-}" ]]; then
    rm -rf "$espresso_tmp"
    espresso_tmp=""
  fi
}

espresso_install() {
  set -euo pipefail
  espresso_is_macos || espresso_die "Espresso is a macOS app. This installer only runs on a Mac."

  local tag url dmg dest
  tag="$espresso_version"
  if [[ -z "$tag" && -z "$espresso_dmg_url" ]]; then
    tag="$(espresso_latest_tag || true)"
  fi
  url="$(espresso_dmg_url_for "$tag")"
  dest="${espresso_install_dir}/Espresso.app"

  espresso_banner
  if [[ -n "$tag" ]]; then
    espresso_step "☕" "Order up: Espresso ${tag}"
  else
    espresso_step "☕" "Order up: latest Espresso"
  fi
  printf '\n'

  espresso_step "①" "Grinding beans (downloading)…"
  espresso_tmp="$(mktemp -d "${TMPDIR:-/tmp}/espresso-brew.XXXXXX")"
  dmg="${espresso_tmp}/Espresso.dmg"
  trap espresso_cleanup EXIT

  curl -fsSL --retry 3 --retry-delay 1 -o "$dmg" "$url" \
    || espresso_die "Could not download ${url}"

  [[ -s "$dmg" ]] || espresso_die "Download was empty. Check ${url}"
  espresso_ok "Beans in the hopper"

  espresso_step "②" "Tamping the puck (mounting)…"
  espresso_mount="$(hdiutil attach -nobrowse -readonly "$dmg" | sed -n 's/.*\(\/Volumes\/.*\)$/\1/p' | tail -n1)"
  [[ -n "$espresso_mount" && -d "$espresso_mount/Espresso.app" ]] \
    || espresso_die "The DMG did not contain Espresso.app"
  espresso_ok "Puck tamped"

  espresso_step "③" "Pulling the shot (installing to ${espresso_install_dir})…"
  espresso_quit_running
  mkdir -p "$espresso_install_dir"
  rm -rf "$dest"
  ditto "$espresso_mount/Espresso.app" "$dest" \
    || espresso_die "Could not copy Espresso.app to ${dest}"
  espresso_ok "Shot pulled"

  espresso_step "④" "Steaming milk (signing, clearing Gatekeeper)…"
  espresso_trust "$dest"
  espresso_ok "No quarantine. No lecture."

  espresso_cleanup
  trap - EXIT

  if [[ "$espresso_launch" == "1" ]]; then
    espresso_step "⑤" "First sip (launching)…"
    open "$dest"
    espresso_ok "Espresso is on the bar — look at the menu bar"
  else
    espresso_ok "Installed at ${dest}"
  fi

  printf '\n  %s\n\n' "$(espresso_c dim "Stay caffeinated.")"
}

if [[ "${BASH_SOURCE[0]:-}" == "$0" || -z "${BASH_SOURCE[0]:-}" ]]; then
  espresso_parse_args "$@"
  espresso_install
fi
