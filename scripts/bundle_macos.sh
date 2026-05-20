#!/bin/sh

set -e

# --- Configuration via environment variables ---
# GAME_VERSION: e.g. "1.8.3"
# ICON_SRC: path to Icon.icns (e.g. from game repo sparse checkout)

: "${GAME_VERSION:?GAME_VERSION is not set}"
: "${ICON_SRC:?ICON_SRC is not set}"

BASE=$(realpath "${1:-.}")

GAME="Link's Awakening DX HD"
GAME_BUNDLE="$BASE/$GAME.app"
LAUNCHER_BUNDLE="$BASE/$GAME Launcher.app"

chmod +x "$BASE/$GAME" "$BASE/Launcher"

mkdir -p "$GAME_BUNDLE/Contents/MacOS"
mkdir -p "$GAME_BUNDLE/Contents/Resources"

cp -p "$BASE/$GAME" "$GAME_BUNDLE/Contents/MacOS/"
cp -p "$BASE/Launcher" "$GAME_BUNDLE/Contents/MacOS/"
cp -p "$ICON_SRC" "$GAME_BUNDLE/Contents/Resources/Icon.icns"
for dylib in "$BASE"/*.dylib; do
    [ -e "$dylib" ] || continue
    cp -p "$dylib" "$GAME_BUNDLE/Contents/MacOS/"
done
cp -Rp "$BASE/Data" "$GAME_BUNDLE/Contents/MacOS/"
cp -Rp "$BASE/Content" "$GAME_BUNDLE/Contents/MacOS/"
[ -d "$BASE/Mods" ] && cp -Rp "$BASE/Mods" "$GAME_BUNDLE/Contents/MacOS/"

# MonoGame expects Content to be placed inside Contents/Resources, while game code
# expects Content to be placed alongside the binary.
# Create a Content symlink so MonoGame and game code finds assets via both search paths.
ln -sf "../MacOS/Content" "$GAME_BUNDLE/Contents/Resources/"

cat <<EOF >"$GAME_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${GAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.projectz.game</string>
    <key>CFBundleIconFile</key>
    <string>Icon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${GAME_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${GAME_VERSION}</string>
</dict>
</plist>
EOF

# Launcher bundle is the same, but changing the executable
cp -Rp "$GAME_BUNDLE" "$LAUNCHER_BUNDLE"
sed -i '' \
    -e "s|<string>${GAME}</string>|<string>Launcher</string>|g" \
    -e "s|com\.projectz\.game|com.projectz.launcher|g" \
    "$LAUNCHER_BUNDLE/Contents/Info.plist"

codesign --sign - --force --deep "$GAME_BUNDLE"
codesign --sign - --force --deep "$LAUNCHER_BUNDLE"
