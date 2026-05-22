#!/usr/bin/env bash

set -euo pipefail

# Finalize a Linux build as an AppImage: merge game and launcher, build AppDir,
# package with appimagetool, then zip for distribution.
#
# Usage: scripts/finalize-linux-appimage.sh <key>
#   key: linux-x64 | linux-arm64
#
# Expects <key>.tar.gz and launcher-<key>.tar.gz in the working directory.
#
# Required environment variables:
#   ICON_SVG  Path to Icon.svg (AppImage desktop icon)
#   ICON_PNG  Path to Icon.png (.DirIcon fallback)

: "${ICON_SVG:?ICON_SVG is not set}"
: "${ICON_PNG:?ICON_PNG is not set}"

KEY="${1:?usage: scripts/finalize-linux-appimage.sh <key>}"
WORK_DIR="work-${KEY}"
GAME_DIR="${WORK_DIR}/game"
LAUNCHER_DIR="${WORK_DIR}/launcher"
APPDIR="appdir-${KEY}"
APPIMAGE_NAME="Link's Awakening DX HD.AppImage"
DESKTOP_NAME="links-awakening-dx-hd"

case "${KEY}" in
linux-x64) ARCH=x86_64 ;;
linux-arm64) ARCH=aarch64 ;;
*)
    echo "Unknown key: ${KEY}"
    exit 1
    ;;
esac

rm -rf "${WORK_DIR}" "${APPDIR}"
rm -f "${APPIMAGE_NAME}" "final-${KEY}-appimage.zip"
mkdir -p "${GAME_DIR}" "${LAUNCHER_DIR}" "${APPDIR}/opt"

tar -xzf "${KEY}.tar.gz" -C "${GAME_DIR}"
tar -xzf "launcher-${KEY}.tar.gz" -C "${LAUNCHER_DIR}"

cp -r "${GAME_DIR}/"* "${APPDIR}/opt/"
cp -r "${LAUNCHER_DIR}/"* "${APPDIR}/opt/"
chmod +x "${APPDIR}/opt/Link's Awakening DX HD" "${APPDIR}/opt/Launcher"

cp "${ICON_SVG}" "${APPDIR}/${DESKTOP_NAME}.svg"
cp "${ICON_PNG}" "${APPDIR}/.DirIcon"

cat >"${APPDIR}/${DESKTOP_NAME}.desktop" <<EOF
[Desktop Entry]
Name=Links Awakening DX HD
Exec=AppRun %F
Icon=${DESKTOP_NAME}
Type=Application
Categories=Game;
EOF

cat >"${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
SELF_DIR="$(dirname "$(readlink -f "$0")")"
if [ "${1:-}" = "--launcher" ]; then
  exec "$SELF_DIR/opt/Launcher" "${@:2}"
else
  exec "$SELF_DIR/opt/Link's Awakening DX HD" "$@"
fi
EOF
chmod +x "${APPDIR}/AppRun"

if [ ! -f appimagetool-x86_64.AppImage ]; then
    curl -fLO --retry 3 --retry-all-errors --retry-delay 5 \
        "https://github.com/AppImage/appimagetool/releases/latest/download/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
fi

ARCH="${ARCH}" ./appimagetool-x86_64.AppImage --appimage-extract-and-run \
    "${APPDIR}" "${APPIMAGE_NAME}"

zip "final-${KEY}-appimage.zip" "${APPIMAGE_NAME}"

rm -rf "${WORK_DIR}" "${APPDIR}" "${APPIMAGE_NAME}"
