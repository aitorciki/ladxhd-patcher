#!/usr/bin/env bash
set -euo pipefail

# Encrypts and uploads local files to Cloudflare R2.
#
# Usage: scripts/r2-upload.sh <basename>...
# Each <basename> is encrypted to ${basename}.gpg and uploaded to
# s3://$R2_BUCKET/$RUN_ID/${basename}.gpg
#
# Required environment variables:
#   R2_BUCKET             R2 bucket name
#   RUN_ID                Run identifier (object key prefix)
#   ASSET_ENCRYPTION_KEY  GPG passphrase for symmetric encryption
#   AWS_ACCESS_KEY_ID     R2 access key
#   AWS_SECRET_ACCESS_KEY R2 secret key
#   AWS_ENDPOINT_URL      R2 S3-compatible endpoint
#   AWS_DEFAULT_REGION    Must be set (use "auto" for Cloudflare R2)

: "${R2_BUCKET:?R2_BUCKET is not set}"
: "${RUN_ID:?RUN_ID is not set}"
: "${ASSET_ENCRYPTION_KEY:?ASSET_ENCRYPTION_KEY is not set}"

MAX_ATTEMPTS=3

for basename in "$@"; do
    gpg --symmetric --cipher-algo AES256 --batch --passphrase "${ASSET_ENCRYPTION_KEY}" "${basename}"
    n=0
    until aws s3 cp "${basename}.gpg" "s3://${R2_BUCKET}/${RUN_ID}/${basename}.gpg"; do
        n=$((n + 1))
        [ "$n" -ge "$MAX_ATTEMPTS" ] && echo "Upload failed after ${MAX_ATTEMPTS} attempts: ${basename}.gpg" >&2 && exit 1
        echo "Retrying upload (attempt $((n + 1))/${MAX_ATTEMPTS})..." >&2
        sleep $((n * 5))
    done
    rm -f "${basename}.gpg"
done
