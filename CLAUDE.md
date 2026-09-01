# Espresso

A macOS menu bar app that wraps `caffeinate` to prevent the Mac from sleeping.
Written in Go. No dock icon (`LSUIElement = true`).

## Project structure

| File | Purpose |
|---|---|
| `caffeinate.go` | Process manager — spawns/kills `caffeinate`, signals expiry |
| `caffeinate_test.go` | Unit tests for the process manager |
| `tray.go` | Menu bar UI, animation ticker, event loop |
| `login.go` + `login.m` | CGO bridge to SMAppService for Login Item registration |
| `main.go` | Entry point — wires Manager → systray, registers login item |
| `Info.plist` | App bundle metadata |
| `Makefile` | Build targets |
| `scripts/install.sh` | Coffee-themed curl\|bash installer (clears Gatekeeper) |
| `installer/` | DMG background, Brew Espresso helper, dmgbuild settings |
| `docs/index.html` | Landing page template — contains `{{VERSION}}` placeholder |
| `.github/workflows/release.yml` | Release pipeline |

## Build & local dev workflow

```bash
make build           # compile + assemble Espresso.app in the project root
make install         # build → ad-hoc sign → install to ~/Applications → launch
make uninstall       # kill running process + remove from ~/Applications
make smoke           # full lifecycle: install, verify running, crash-check, uninstall
make dmg             # build a coffee-themed Espresso.dmg (macOS only)
make test-installer  # installer script tests (Linux-safe)
make clean           # remove binary, Espresso.app, DMG, and any generated iconset
```

`make install` clears the Gatekeeper quarantine flag, so the app opens without
needing "Open Anyway" or right-click → Open. Use this during development.

Requires macOS and Go 1.21+. The CGO login item code links against
ServiceManagement and Foundation frameworks — no extra setup needed.

## Run tests

```bash
go test ./... -v
make test-installer
```

## End-user install (unsigned, no Apple Developer ID)

Espresso is **ad-hoc signed**, not notarized. Browser-downloaded apps get a
quarantine flag and Gatekeeper blocks them. The supported install is brew
from Terminal — it never leaves quarantine set:

```bash
curl -fsSL https://eng-kitchen.github.io/espresso/install.sh | bash
```

From this repo during development: `make install`.

Do not manually edit a version string into `docs/index.html`. The
`{{VERSION}}` placeholder is replaced at deploy time.

## Release workflow

To ship a new version:

```bash
git tag v1.x.x
git push --tags
```

GitHub Actions takes it from there:
1. Builds `Espresso.app` on a macOS runner
2. Packages a coffee-themed `Espresso.dmg` (background, Applications link, Brew helper)
3. Injects the version into the landing page, copies `install.sh`, deploys GitHub Pages
4. Creates a GitHub Release and attaches `Espresso.dmg` plus a SHA-256 checksum

**Important:** `docs/index.html` contains a `{{VERSION}}` placeholder that
Actions replaces at deploy time. Do not manually edit the version string in
that file — Actions processes it at deploy time into `_site/index.html`; `docs/index.html` always stays as the `{{VERSION}}` template.

## GitHub Pages

The landing page is served from GitHub Pages.
Source must be set to **"GitHub Actions"** in repo Settings → Pages.
`install.sh` is published next to the page so the brew one-liner stays stable.
