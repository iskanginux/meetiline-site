#!/bin/sh
# Meetiline installer: downloads the latest version, puts it in Applications and opens it.
# Read it before running it: this is all it does.
set -eu

URL="https://github.com/iskanginux/meetiline-site/releases/latest/download/Meetiline.dmg"
DEST="${MEETILINE_DEST:-/Applications}"

[ "$(uname -s)" = Darwin ] || { echo "Meetiline is a Mac app."; exit 1; }
[ "$(uname -m)" = arm64 ] || { echo "Meetiline needs a Mac with Apple silicon (M1 or newer)."; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || { echo "Meetiline needs macOS 14 or later."; exit 1; }

TMP="$(mktemp -d)"
cleanup() { hdiutil detach -quiet "$TMP/disk" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

echo "Downloading Meetiline…"
curl -fL --progress-bar "$URL" -o "$TMP/Meetiline.dmg"
hdiutil attach -nobrowse -readonly -quiet -mountpoint "$TMP/disk" "$TMP/Meetiline.dmg"

[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
if pgrep -xq Meetiline; then osascript -e 'quit app "Meetiline"' >/dev/null 2>&1 || true; sleep 1; fi
rm -rf "$DEST/Meetiline.app"
ditto "$TMP/disk/Meetiline.app" "$DEST/Meetiline.app"
# Not notarized yet: this is what lets it open without the "can't be checked" warning.
xattr -dr com.apple.quarantine "$DEST/Meetiline.app" 2>/dev/null || true

echo "Meetiline is in $DEST."
[ -n "${MEETILINE_NO_OPEN:-}" ] || open "$DEST/Meetiline.app"
