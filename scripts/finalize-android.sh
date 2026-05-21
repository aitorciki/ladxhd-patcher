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
PACKAGE_DIR="${STAGING_DIR}/Links Awakening DX HD"

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
rm -f final-android.zip
mkdir -p "${WORK_PACKAGE_DIR}" "${PACKAGE_DIR}"

tar -xzf android.tar.gz -C "${WORK_PACKAGE_DIR}"
rm -f "${WORK_PACKAGE_DIR}/_Microsoft.Android.Resource.Designer.dll"
rm -f "${WORK_PACKAGE_DIR}/com.zelda.ladxhd.apk"
mv "${WORK_PACKAGE_DIR}/com.zelda.ladxhd-Signed.apk" "${WORK_PACKAGE_DIR}/com.zelda.ladxhd.apk"
mv "${WORK_PACKAGE_DIR}"/* "${PACKAGE_DIR}/"

(
    cd "${STAGING_DIR}"
    zip -r ../final-android.zip "Links Awakening DX HD"
)

rm -rf "${WORK_DIR}" "${STAGING_DIR}"
