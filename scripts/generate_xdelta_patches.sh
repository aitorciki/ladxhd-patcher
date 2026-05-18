#!/usr/bin/env bash
set -euo pipefail

# Generate xdelta3 patches in parallel, bounded by CPU count.
# Usage: generate_xdelta_patches.sh <source.zip> <key1> <key2> ...
#
# For each key, runs: xdelta3 -e -s <source.zip> final-<key>.zip <key>.xdelta

SOURCE="$1"
shift

NPROC=$(nproc)

generate_one() {
  local key="$1"
  echo "Generating patch for ${key}..."
  xdelta3 -e -s "${SOURCE}" "final-${key}.zip" "${key}.xdelta"
  echo "Done: ${key}.xdelta"
}

# Launch up to NPROC concurrent jobs, queuing the rest.
for key in "$@"; do
  generate_one "$key" &

  # If we've reached the concurrency limit, wait for at least one job to finish.
  if [ "$(jobs -r | wc -l)" -ge "$NPROC" ]; then
    wait -n
  fi
done

# Wait for all remaining jobs.
wait

echo "All patches generated."
