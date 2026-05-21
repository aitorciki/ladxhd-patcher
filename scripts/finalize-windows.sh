#!/usr/bin/env bash

set -euo pipefail

# Finalize a Windows build: merge game and launcher, then zip for distribution.
#
# Usage: scripts/finalize-windows.sh <key>
#   key: windows-dx | windows-gl
#
# Expects <key>.tar.gz and launcher-windows.tar.gz in the working directory.

KEY="${1:?usage: scripts/finalize-windows.sh <key>}"
WORK_DIR="work-${KEY}"
STAGING_DIR="staging-${KEY}"
PACKAGE_DIR="${STAGING_DIR}/Links Awakening DX HD"

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
rm -f "final-${KEY}.zip"
mkdir -p "${WORK_DIR}" "${PACKAGE_DIR}"

tar -xzf "${KEY}.tar.gz" -C "${WORK_DIR}"
tar -xzf launcher-windows.tar.gz -C "${WORK_DIR}"

rm -f "${WORK_DIR}/nfd.lib" "${WORK_DIR}/nfd.pdb"
mv "${WORK_DIR}"/* "${PACKAGE_DIR}/"

(
    cd "${STAGING_DIR}"
    7z a -r "../final-${KEY}.zip" "Links Awakening DX HD"
)

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
