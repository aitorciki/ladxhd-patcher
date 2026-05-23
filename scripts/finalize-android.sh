#!/usr/bin/env bash

set -euo pipefail

# Finalize the Android build: clean up artifacts, then zip for distribution.
#
# Usage: scripts/finalize-android.sh
#
# Expects android.tar.gz in the working directory.

WORK_DIR="work-android"
STAGING_DIR="staging-android"
WORK_PACKAGE_DIR="${WORK_DIR}/Links Awakening DX HD"

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
rm -f final-android.zip
mkdir -p "${WORK_PACKAGE_DIR}" "${STAGING_DIR}"

tar -xzf android.tar.gz -C "${WORK_PACKAGE_DIR}"
mv "${WORK_PACKAGE_DIR}/com.zelda.ladxhd-Signed.apk" "${STAGING_DIR}/com.zelda.ladxhd.apk"

(
    cd "${STAGING_DIR}"
    zip -r ../final-android.zip com.zelda.ladxhd.apk
)

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
