#!/usr/bin/env bash

set -euo pipefail

# Finalize a macOS build: merge game and launcher, bundle .app packages, then zip.
#
# Usage: scripts/finalize-macos.sh <key>
#   key: macos-arm64 | macos-x64
#
# Expects <key>.tar.gz and launcher-<key>.tar.gz in the working directory.
#
# Required environment variables:
#   GAME_VERSION  Version string, e.g. "1.8.3"
#   ICON_SRC      Path to Icon.icns

: "${GAME_VERSION:?GAME_VERSION is not set}"
: "${ICON_SRC:?ICON_SRC is not set}"

KEY="${1:?usage: scripts/finalize-macos.sh <key>}"
WORK_DIR="work-${KEY}"
GAME_EXE="Link's Awakening DX HD"
GAME_BUNDLE="${WORK_DIR}/${GAME_EXE}.app"
LAUNCHER_BUNDLE="${WORK_DIR}/${GAME_EXE} Launcher.app"
GAME_STAGING_DIR="staging-${KEY}-game"
LAUNCHER_STAGING_DIR="staging-${KEY}-launcher"
GAME_PACKAGE_DIR="${GAME_STAGING_DIR}/Links Awakening DX HD"
LAUNCHER_PACKAGE_DIR="${LAUNCHER_STAGING_DIR}/Links Awakening DX HD"

rm -rf "${WORK_DIR}" "${GAME_STAGING_DIR}" "${LAUNCHER_STAGING_DIR}"
rm -f "final-${KEY}-game.zip" "final-${KEY}-launcher.zip"
mkdir -p "${WORK_DIR}" "${GAME_PACKAGE_DIR}" "${LAUNCHER_PACKAGE_DIR}"

tar -xzf "${KEY}.tar.gz" -C "${WORK_DIR}"
tar -xzf "launcher-${KEY}.tar.gz" -C "${WORK_DIR}"

chmod +x "${WORK_DIR}/${GAME_EXE}" "${WORK_DIR}/Launcher"

mkdir -p "${GAME_BUNDLE}/Contents/MacOS"
mkdir -p "${GAME_BUNDLE}/Contents/Resources"

cp -p "${WORK_DIR}/${GAME_EXE}" "${GAME_BUNDLE}/Contents/MacOS/"
cp -p "${WORK_DIR}/Launcher" "${GAME_BUNDLE}/Contents/MacOS/"
cp -p "${ICON_SRC}" "${GAME_BUNDLE}/Contents/Resources/Icon.icns"
for dylib in "${WORK_DIR}"/*.dylib; do
    [ -e "${dylib}" ] || continue
    cp -p "${dylib}" "${GAME_BUNDLE}/Contents/MacOS/"
done
cp -Rp "${WORK_DIR}/Data" "${GAME_BUNDLE}/Contents/MacOS/"
cp -Rp "${WORK_DIR}/Content" "${GAME_BUNDLE}/Contents/MacOS/"
[ -d "${WORK_DIR}/Mods" ] && cp -Rp "${WORK_DIR}/Mods" "${GAME_BUNDLE}/Contents/MacOS/"

# MonoGame expects Content inside Contents/Resources while game code expects it
# alongside the binary, so provide both paths with a symlink.
ln -sf "../MacOS/Content" "${GAME_BUNDLE}/Contents/Resources/"

cat <<EOF >"${GAME_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${GAME_EXE}</string>
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

cp -Rp "${GAME_BUNDLE}" "${LAUNCHER_BUNDLE}"
sed -i '' \
    -e "s|<string>${GAME_EXE}</string>|<string>Launcher</string>|g" \
    -e "s|com\.projectz\.game|com.projectz.launcher|g" \
    "${LAUNCHER_BUNDLE}/Contents/Info.plist"

codesign --sign - --force --deep "${GAME_BUNDLE}"
codesign --sign - --force --deep "${LAUNCHER_BUNDLE}"

cp -RPp "${GAME_BUNDLE}" "${GAME_PACKAGE_DIR}/"
cp -RPp "${LAUNCHER_BUNDLE}" "${LAUNCHER_PACKAGE_DIR}/"

(
    cd "${GAME_STAGING_DIR}"
    zip -ry "../final-${KEY}-game.zip" "Links Awakening DX HD"
)

(
    cd "${LAUNCHER_STAGING_DIR}"
    zip -ry "../final-${KEY}-launcher.zip" "Links Awakening DX HD"
)

rm -rf "${WORK_DIR}" "${GAME_STAGING_DIR}" "${LAUNCHER_STAGING_DIR}"
