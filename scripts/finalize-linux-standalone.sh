#!/usr/bin/env bash

set -euo pipefail

# Finalize a Linux build: merge game and launcher, then zip for distribution.
#
# Usage: scripts/finalize-linux-standalone.sh <key>
#   key: linux-x64 | linux-arm64
#
# Expects <key>.tar.gz and launcher-<key>.tar.gz in the working directory.

KEY="${1:?usage: scripts/finalize-linux-standalone.sh <key>}"

case "${KEY}" in
linux-x64) OUTPUT_KEY="linux-x64-standalone" ;;
linux-arm64) OUTPUT_KEY="linux-arm64-standalone" ;;
*)
    echo "Unknown key: ${KEY}" >&2
    exit 1
    ;;
esac

WORK_DIR="work-${KEY}"
GAME_DIR="${WORK_DIR}/game"
LAUNCHER_DIR="${WORK_DIR}/launcher"
STAGING_DIR="staging-${OUTPUT_KEY}"
PACKAGE_DIR="${STAGING_DIR}/Links Awakening DX HD"

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
rm -f "final-${OUTPUT_KEY}.zip"
mkdir -p "${GAME_DIR}" "${LAUNCHER_DIR}" "${PACKAGE_DIR}"

tar -xzf "${KEY}.tar.gz" -C "${GAME_DIR}"
tar -xzf "launcher-${KEY}.tar.gz" -C "${LAUNCHER_DIR}"

cp -r "${LAUNCHER_DIR}"/* "${GAME_DIR}/"
chmod +x "${GAME_DIR}/Link's Awakening DX HD" "${GAME_DIR}/Launcher"
mv "${GAME_DIR}"/* "${PACKAGE_DIR}/"

(
    cd "${STAGING_DIR}"
    zip -r "../final-${OUTPUT_KEY}.zip" "Links Awakening DX HD"
)

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
