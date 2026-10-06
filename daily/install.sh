#!/bin/sh
# Meetiline Daily installer: downloads the latest version, checks it, puts it in Applications and opens it.
# Read it before running it: this is all it does. (Everything is inside main, so a cut-off download runs nothing.)
set -eu

main() {
  BASE="https://github.com/iskanginux/meetiline-daily-site/releases/download/v0.4.2"
  FILE="Meetiline-Daily.dmg"
  SHA256="4c75aff7126d74e5a3f5b3631cdae2223e90a346cb7b8b5f2c81b4ee7186907a"
  APP="Meetiline Daily"
  BUNDLE_ID="app.meetiline.mac.daily"
  DEST="${MEETILINE_DEST:-/Applications}"

  [ "$(uname -s)" = Darwin ] || { echo "Meetiline Daily is a Mac app."; exit 1; }
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ] || { echo "Meetiline Daily needs a Mac with Apple silicon (M1 or newer)."; exit 1; }
  OS="$(sw_vers -productVersion)"
  MAJOR="$(echo "$OS" | cut -d. -f1)"; MINOR="$(echo "$OS" | cut -d. -f2)"; MINOR="${MINOR:-0}"
  if [ "$MAJOR" -lt 14 ] || { [ "$MAJOR" -eq 14 ] && [ "$MINOR" -lt 2 ]; }; then
    echo "Meetiline Daily needs macOS 14.2 or later (this is $OS)."; exit 1
  fi

  TMP="$(mktemp -d)"
  cleanup() { hdiutil detach -quiet "$TMP/disk" 2>/dev/null || true; rm -rf "$TMP"; }
  trap cleanup EXIT
  trap 'exit 1' INT TERM

  echo "Downloading ${APP}…"
  curl -fL --proto '=https' --proto-redir '=https' --tlsv1.2 --progress-bar "$BASE/$FILE" -o "$TMP/$FILE" ||
    { echo "Could not download $BASE/$FILE"; exit 1; }
  GOT="$(shasum -a 256 "$TMP/$FILE" | cut -d' ' -f1)"
  [ "$GOT" = "$SHA256" ] || { echo "The download does not match its checksum, so it was not installed."; echo "  expected $SHA256"; echo "  got      $GOT"; exit 1; }
  hdiutil attach -nobrowse -readonly -quiet -mountpoint "$TMP/disk" "$TMP/$FILE" </dev/null
  [ -d "$TMP/disk/$APP.app" ] || { echo "The disk image has no $APP.app."; exit 1; }
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TMP/disk/$APP.app/Contents/Info.plist")" = "$BUNDLE_ID" ] || { echo "Unexpected app in the disk image."; exit 1; }

  if [ ! -w "$DEST" ]; then
    echo "Note: $DEST is not writable here, so $APP goes to ~/Applications. The Claude connection in Settings needs it in /Applications: move it there by hand."
    DEST="$HOME/Applications"
  fi
  mkdir -p "$DEST"
  RUNNING="$DEST/$APP.app/Contents/MacOS/Meetiline"
  if pgrep -f "$RUNNING" >/dev/null 2>&1; then
    echo "$APP is running: closing it (a recording in progress would end)."
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do pgrep -f "$RUNNING" >/dev/null 2>&1 || break; sleep 0.5; done
    if pgrep -f "$RUNNING" >/dev/null 2>&1; then echo "$APP is still running. Quit it and run this again."; exit 1; fi
  fi
  # The new copy is made first; the old one is only set aside, and put back if anything fails.
  ditto "$TMP/disk/$APP.app" "$TMP/new.app"
  [ ! -d "$DEST/$APP.app" ] || mv "$DEST/$APP.app" "$TMP/old.app"
  if ! mv "$TMP/new.app" "$DEST/$APP.app"; then
    [ ! -d "$TMP/old.app" ] || mv "$TMP/old.app" "$DEST/$APP.app"
    echo "Could not put $APP in $DEST."; exit 1
  fi
  # The app is not notarized yet: this lets it open without the "can't be checked" warning.
  xattr -dr com.apple.quarantine "$DEST/$APP.app" 2>/dev/null || true

  echo "$APP is in $DEST."
  echo "It records calls: you are responsible for recording lawfully, and for telling the others and asking their consent where the law requires it."
  echo "On first launch it asks to use the microphone, the sound of call apps, your screen and notifications, and downloads the speech model (about 0.6–0.9 GB) once."
  [ -n "${MEETILINE_NO_OPEN:-}" ] || open "$DEST/$APP.app"
}

main "$@"
