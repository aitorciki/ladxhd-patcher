#!/usr/bin/env bash
set -euo pipefail

# Downloads and decrypts artifacts from Cloudflare R2.
#
# Usage: scripts/r2-download.sh <basename>...
# Each <basename> corresponds to s3://$R2_BUCKET/$RUN_ID/${basename}.gpg
#
# Required environment variables:
#   R2_BUCKET             R2 bucket name
#   RUN_ID                Run identifier (object key prefix)
#   ASSET_ENCRYPTION_KEY  GPG passphrase for symmetric decryption
#   AWS_ACCESS_KEY_ID     R2 access key
#   AWS_SECRET_ACCESS_KEY R2 secret key
#   AWS_ENDPOINT_URL      R2 S3-compatible endpoint
#   AWS_DEFAULT_REGION    Must be set (use "auto" for Cloudflare R2)

: "${R2_BUCKET:?R2_BUCKET is not set}"
: "${RUN_ID:?RUN_ID is not set}"
: "${ASSET_ENCRYPTION_KEY:?ASSET_ENCRYPTION_KEY is not set}"

MAX_ATTEMPTS=3

for basename in "$@"; do
    n=0
    until aws s3 cp "s3://${R2_BUCKET}/${RUN_ID}/${basename}.gpg" "${basename}.gpg"; do
        n=$((n + 1))
        [ "$n" -ge "$MAX_ATTEMPTS" ] && echo "Download failed after ${MAX_ATTEMPTS} attempts: ${basename}.gpg" >&2 && exit 1
        echo "Retrying download (attempt $((n + 1))/${MAX_ATTEMPTS})..." >&2
        rm -f "${basename}.gpg"
        sleep $((n * 5))
    done
    gpg --decrypt --batch --passphrase "${ASSET_ENCRYPTION_KEY}" "${basename}.gpg" >"${basename}"
    rm -f "${basename}.gpg"
done
