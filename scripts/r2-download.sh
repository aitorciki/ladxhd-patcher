#!/bin/sh
set -e

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

for basename in "$@"; do
    aws s3 cp "s3://${R2_BUCKET}/${RUN_ID}/${basename}.gpg" "${basename}.gpg"
    gpg --decrypt --batch --passphrase "${ASSET_ENCRYPTION_KEY}" "${basename}.gpg" >"${basename}"
    rm -f "${basename}.gpg"
done
