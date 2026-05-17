#!/bin/sh

set -e

# --- Configuration via environment variables ---
# GAME_VERSION: e.g. "1.8.3"
# GAME_ARCH: e.g. "arm64" or "x86_64"
# ICON_SRC: path to Icon.icns (e.g. from game repo sparse checkout)

VERSION="${GAME_VERSION:-1.8.3}"
ARCH="${GAME_ARCH:-arm64}"

CURRENT_DIR=$(pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'ladxhd-app-bundle')
BASE=$(realpath "${1:-.}")

cleanup() {
    cd "$CURRENT_DIR"
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

NAME="Link's Awakening DX HD"
BUNDLE="$BASE/$NAME.app"
BUNDLE_TMP="$TMP_DIR/$NAME.app"

# Set executable bit on the standalone binary.
chmod +x "$BASE/$NAME"

# Ad-hoc codesign executable files (binary and dylibs).
codesign --sign - --force "$BASE/$NAME"
for dylib in libopenal.dylib libSDL2-2.0.0.dylib; do
    [ -f "$BASE/$dylib" ] && codesign --sign - --force "$BASE/$dylib"
done

# Create bundle directory structure inside temp directory.
# The bundle is only moved into BASE once all steps succeed , so a failure
# at any point leaves nothing malformed in the game directory.
mkdir -p "$BUNDLE_TMP/Contents/MacOS"
mkdir -p "$BUNDLE_TMP/Contents/Resources"

# Copy the signed binary and dylibs into Contents/MacOS/ preserving permissions.
cp -p "$BASE/$NAME" "$BUNDLE_TMP/Contents/MacOS/$NAME"
for dylib in libopenal.dylib libSDL2-2.0.0.dylib; do
    [ -f "$BASE/$dylib" ] && cp -p "$BASE/$dylib" "$BUNDLE_TMP/Contents/MacOS/$dylib"
done

# Copy Data, Content, and Mods into Contents/MacOS/.
[ -d "$BASE/Data" ] && cp -rp "$BASE/Data" "$BUNDLE_TMP/Contents/MacOS/Data"
[ -d "$BASE/Content" ] && cp -rp "$BASE/Content" "$BUNDLE_TMP/Contents/MacOS/Content"
[ -d "$BASE/Mods" ] && cp -rp "$BASE/Mods" "$BUNDLE_TMP/Contents/MacOS/Mods"

# MonogGame expects Content to be placed inside Contents/Resources, while game code
# expects Content to be placed alongside the binary.
# Create a Content symlink so MonoGame and game code finds assets via both search paths.
ln -sf "../MacOS/Content" "$BUNDLE_TMP/Contents/Resources/Content"

# Copy bundle-specific resources.
if [ -n "$ICON_SRC" ] && [ -f "$ICON_SRC" ]; then
    cp -p "$ICON_SRC" "$BUNDLE_TMP/Contents/Resources/Icon.icns"
else
    echo "Warning: Icon.icns not found at ICON_SRC=$ICON_SRC" >&2
fi

cat <<EOF >"$BUNDLE_TMP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${NAME}</string>
    <key>CFBundleIconFile</key>
    <string>Icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.projectz.game</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleSignature</key>
    <string>FONV</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>LSArchitecturePriority</key>
    <array>
        <string>${ARCH}</string>
    </array>
</dict>
</plist>
EOF

# Codesign the app bundle.
codesign --sign - --force --deep "$BUNDLE_TMP"

# Atomically move the completed bundle into BASE, replacing any stale copy.
rm -rf "$BUNDLE"
mv "$BUNDLE_TMP" "$BUNDLE"

# If the Launcher binary is present, make it executable and create its own app bundle.
# The Launcher app bundle includes the game to allow launching it easily.
if [ -f "$BASE/Launcher" ]; then
    chmod +x "$BASE/Launcher"

    codesign --sign - --force "$BASE/Launcher"
    for dylib in libAvaloniaNative.dylib libHarfBuzzSharp.dylib libSkiaSharp.dylib; do
        [ -f "$BASE/$dylib" ] && codesign --sign - --force "$BASE/$dylib"
    done

    LAUNCHER_BUNDLE="$BASE/$NAME Launcher.app"
    LAUNCHER_TMP="$TMP_DIR/$NAME Launcher.app"

    # Copy the completed game bundle as the foundation (includes all game data, Content, Mods).
    cp -RPp "$BUNDLE" "$LAUNCHER_TMP"

    # Add the Launcher binary and its Avalonia/Skia dylibs on top.
    cp -p "$BASE/Launcher" "$LAUNCHER_TMP/Contents/MacOS/Launcher"
    for dylib in libAvaloniaNative.dylib libHarfBuzzSharp.dylib libSkiaSharp.dylib; do
        [ -f "$BASE/$dylib" ] && cp -p "$BASE/$dylib" "$LAUNCHER_TMP/Contents/MacOS/$dylib"
    done

    # Write a launcher-specific Info.plist derived from the game bundle's plist.
    # Substitutes CFBundleExecutable (the game name) with "Launcher",
    # and changes CFBundleIdentifier from com.projectz.game to com.projectz.launcher.
    sed -e "s|<string>${NAME}</string>|<string>Launcher</string>|g" \
        -e "s|com\.projectz\.game|com.projectz.launcher|g" \
        "$BUNDLE/Contents/Info.plist" >"$LAUNCHER_TMP/Contents/Info.plist"

    # Codesign the app bundle.
    codesign --sign - --force --deep "$LAUNCHER_TMP"

    # Atomically move the completed launcher bundle into BASE, replacing any stale copy.
    rm -rf "$LAUNCHER_BUNDLE"
    mv "$LAUNCHER_TMP" "$LAUNCHER_BUNDLE"
fi
