#!/usr/bin/env bash

set -euo pipefail

# Download and apply release xdelta patches against a v1.0.0 zip.

ALL_KEYS=(
  windows-dx11 windows-gl
  linux-x64-standalone linux-arm64-standalone linux-x64-appimage linux-arm64-appimage
  macos-arm64-game macos-arm64-launcher macos-x64-game macos-x64-launcher
  android
)

VALID_PLATFORMS=(
  windows-dx11 windows-gl
  linux-x64 linux-arm64 linux-x64-appimage linux-arm64-appimage
  macos-arm64 macos-arm64-launcher macos-x64 macos-x64-launcher
  android
)

DEFAULT_V1_ZIP="Links Awakening DX HD v1.0.0.zip"

SCRIPT_NAME="$(basename "$0")"

print_usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--source <v1.zip>] [--release <release>] [--platform <platform>]... [--enable-mods]

Download and apply release xdelta patches against a v1.0.0 zip.

Flags:
  -s, --source     Path to the v1.0.0 zip archive (default: "${DEFAULT_V1_ZIP}" in the current directory)
  -r, --release    Release to download patches from (default: latest)
  -p, --platform   Platform to patch; repeat to patch multiple platforms (default: current host platform)
  --enable-mods    Flatten v1.0.0 Data and Content into each build's Data/Backup for mod compatibility
  -h, --help       Show this help message

Valid releases:
  latest                 Resolve the latest GitHub release tag
  nightly                Download patches from the nightly release
  <github-release-tag>   Any explicit GitHub release tag

Valid platforms:
  all
  windows-dx11
  windows-gl
  linux-x64
  linux-arm64
  linux-x64-appimage
  linux-arm64-appimage
  macos-arm64
  macos-arm64-launcher
  macos-x64
  macos-x64-launcher
  android

Notes:
  * Omitting --platform selects the current host platform.
  * Repeating --platform patches each requested platform.
  * On Windows, the detected default is windows-dx11.
  * linux-x64 maps internally to linux-x64-standalone.
  * linux-arm64 maps internally to linux-arm64-standalone.
  * macos-arm64 maps internally to macos-arm64-game.
  * macos-x64 maps internally to macos-x64-game.
  * Output is written to ./patched/<platform>/.
  * Downloaded patches are stored in a temporary directory and cleaned up automatically.
  * --enable-mods is supported by windows, linux standalone, and macos builds; it is
  ignored (with a notice) for android and linux appimages.
EOF
}

detect_host_platform() {
  local os arch

  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
  Darwin)
    case "$arch" in
    arm64) printf '%s\n' "macos-arm64" ;;
    x86_64) printf '%s\n' "macos-x64" ;;
    *) return 1 ;;
    esac
    ;;
  Linux)
    case "$arch" in
    x86_64) printf '%s\n' "linux-x64" ;;
    aarch64 | arm64) printf '%s\n' "linux-arm64" ;;
    *) return 1 ;;
    esac
    ;;
  MINGW* | MSYS* | CYGWIN*)
    printf '%s\n' "windows-dx11"
    ;;
  *)
    return 1
    ;;
  esac
}

platform_for_key() {
  case "$1" in
  linux-x64-standalone) printf '%s\n' "linux-x64" ;;
  linux-arm64-standalone) printf '%s\n' "linux-arm64" ;;
  macos-arm64-game) printf '%s\n' "macos-arm64" ;;
  macos-x64-game) printf '%s\n' "macos-x64" ;;
  *) printf '%s\n' "$1" ;;
  esac
}

enable_mods_for_key() {
  local key="$1"
  local platform_dir="$2"
  local data_dir

  case "$key" in
  windows-dx11 | windows-gl | linux-x64-standalone | linux-arm64-standalone)
    data_dir="${platform_dir}/Links Awakening DX HD/Data"
    ;;
  macos-arm64-game | macos-x64-game | macos-arm64-launcher | macos-x64-launcher)
    data_dir=$(find "${platform_dir}" -maxdepth 4 -type d -name Data -path "*.app/Contents/MacOS/Data" | head -1)
    ;;
  linux-x64-appimage | linux-arm64-appimage | android)
    echo "Notice: --enable-mods is not supported for '${key}', skipping mod enablement." >&2
    return 0
    ;;
  *)
    echo "Notice: --enable-mods is not implemented for '${key}', skipping mod enablement." >&2
    return 0
    ;;
  esac

  if [ -z "$data_dir" ] || [ ! -d "$data_dir" ]; then
    echo "Warning: could not locate Data directory for '${key}' under '${platform_dir}', skipping mod enablement." >&2
    return 0
  fi

  if [ -z "${V1_DATA_DIR:-}" ] || [ ! -d "${V1_DATA_DIR:-}" ]; then
    echo "Warning: v1.0.0 Data directory not available, skipping mod enablement for '${key}'." >&2
    return 0
  fi
  if [ -z "${V1_CONTENT_DIR:-}" ] || [ ! -d "${V1_CONTENT_DIR:-}" ]; then
    echo "Warning: v1.0.0 Content directory not available, skipping mod enablement for '${key}'." >&2
    return 0
  fi

  local backup_dir="${data_dir}/Backup"
  mkdir -p "$backup_dir"
  find "$V1_DATA_DIR" "$V1_CONTENT_DIR" -type f -exec sh -c 'cp "$@" "$0"/' "$backup_dir" {} +
  echo "Enabled mods for '${key}': flattened v1.0.0 Data/Content into ${backup_dir}/"
}

# --- finalization functions ---

# if a function named finalize_$platform is found, it will be
# called after the patching process has succeeded, e.g.:

#finalize_android() {
#    local dir="$1"
#    local release="$2"
#
#    apksigner sign "${dir}/com.zelda.ladxhd.apk"
#    rm -f "${dir}/com.zelda.ladxhd.apk.idsig"
#}

# --- argument parsing ---

V1_ZIP=""
RELEASE="latest"
PLATFORMS=()
ENABLE_MODS=false

while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    print_usage
    exit 0
    ;;
  -s | --source)
    if [ $# -lt 2 ]; then
      echo "Error: missing value for '$1'." >&2
      echo "Run '${SCRIPT_NAME} --help' for usage." >&2
      exit 1
    fi
    V1_ZIP="$2"
    shift 2
    ;;
  -r | --release)
    if [ $# -lt 2 ]; then
      echo "Error: missing value for '$1'." >&2
      echo "Run '${SCRIPT_NAME} --help' for usage." >&2
      exit 1
    fi
    RELEASE="$2"
    shift 2
    ;;
  -p | --platform)
    if [ $# -lt 2 ]; then
      echo "Error: missing value for '$1'." >&2
      echo "Run '${SCRIPT_NAME} --help' for usage." >&2
      exit 1
    fi
    PLATFORMS+=("$2")
    shift 2
    ;;
  --enable-mods)
    ENABLE_MODS=true
    shift
    ;;
  -*)
    echo "Error: unknown option '$1'." >&2
    echo "Run '${SCRIPT_NAME} --help' for usage." >&2
    exit 1
    ;;
  *)
    echo "Error: unexpected positional argument '$1'." >&2
    echo "Run '${SCRIPT_NAME} --help' for usage." >&2
    exit 1
    ;;
  esac
done

if [ -z "$V1_ZIP" ]; then
  V1_ZIP="$DEFAULT_V1_ZIP"
  echo "Using default source: $V1_ZIP"
fi

if [ "${#PLATFORMS[@]}" -eq 0 ]; then
  if ! HOST_PLATFORM="$(detect_host_platform)"; then
    echo "Error: could not detect a supported host platform from $(uname -s)/$(uname -m)." >&2
    echo "Specify one explicitly with '${SCRIPT_NAME} --platform <platform>' or run '${SCRIPT_NAME} --help'." >&2
    exit 1
  fi
  PLATFORMS=("$HOST_PLATFORM")
fi

# --- tool checks ---

for tool in gh xdelta3 unzip; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Error: required tool '$tool' not found in PATH." >&2
    exit 1
  fi
done

if [ ! -f "$V1_ZIP" ]; then
  echo "Error: v1.0.0 zip not found: $V1_ZIP" >&2
  echo "Run '${SCRIPT_NAME} --help' for usage." >&2
  exit 1
fi

# --- determine keys to process ---

KEYS=()
ALL_PLATFORMS=false

for platform in "${PLATFORMS[@]}"; do
  if [ "$platform" = "all" ]; then
    KEYS=("${ALL_KEYS[@]}")
    ALL_PLATFORMS=true
    break
  fi

  VALID=false
  for valid_platform in "${VALID_PLATFORMS[@]}"; do
    if [ "$platform" = "$valid_platform" ]; then
      VALID=true
      break
    fi
  done

  if [ "$VALID" != "true" ]; then
    echo "Error: unsupported platform '$platform'." >&2
    echo "Supported platforms: all ${VALID_PLATFORMS[*]}" >&2
    echo "Run '${SCRIPT_NAME} --help' for usage." >&2
    exit 1
  fi

  case "$platform" in
  linux-x64) key="linux-x64-standalone" ;;
  linux-arm64) key="linux-arm64-standalone" ;;
  macos-arm64) key="macos-arm64-game" ;;
  macos-x64) key="macos-x64-game" ;;
  *) key="$platform" ;;
  esac

  duplicate=false
  for existing_key in "${KEYS[@]}"; do
    if [ "$key" = "$existing_key" ]; then
      duplicate=true
      break
    fi
  done

  if [ "$duplicate" != "true" ]; then
    KEYS+=("$key")
  fi
done

# --- resolve release tag ---

if [ "$RELEASE" = "latest" ]; then
  RELEASE=$(gh release view --repo aitorciki/ladxhd-patcher --json tagName --jq '.tagName')
  echo "Resolved latest release: $RELEASE"
fi

if [ "$ALL_PLATFORMS" = "true" ]; then
  echo "Preparing patches for release '${RELEASE}' on all platforms."
elif [ "${#PLATFORMS[@]}" -eq 1 ] && [ "${PLATFORMS[0]}" != "${KEYS[0]}" ]; then
  echo "Preparing patches for release '${RELEASE}' on platform '${PLATFORMS[0]}' (internal key: '${KEYS[0]}')."
elif [ "${#PLATFORMS[@]}" -gt 1 ]; then
  echo "Preparing patches for release '${RELEASE}' on platforms: ${PLATFORMS[*]}"
else
  echo "Preparing patches for release '${RELEASE}' on platform '${PLATFORMS[0]}'."
fi

if [ "$ENABLE_MODS" = "true" ]; then
  echo "Mod compatibility is enabled: v1.0.0 Data/Content will be flattened into each build's Data/Backup/."
fi

OUT_DIR="patched"
PATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/patch-release.XXXXXX")"
mkdir -p "$OUT_DIR"

cleanup() {
  rm -rf "$PATCH_DIR"
}

trap cleanup EXIT

# --- extract v1.0.0 zip for mod enablement ---

V1_DATA_DIR=""
V1_CONTENT_DIR=""

if [ "$ENABLE_MODS" = "true" ]; then
  V1_EXTRACT_DIR="${PATCH_DIR}/v1"
  echo "Extracting v1.0.0 zip for mod enablement..."
  unzip -qo "$V1_ZIP" -d "$V1_EXTRACT_DIR"

  V1_GAME_DIR=$(find "$V1_EXTRACT_DIR" -maxdepth 2 -type d -name Data | head -1)
  if [ -n "$V1_GAME_DIR" ]; then
    V1_GAME_DIR=$(dirname "$V1_GAME_DIR")
  fi

  if [ -n "$V1_GAME_DIR" ] && [ -d "${V1_GAME_DIR}/Data" ]; then
    V1_DATA_DIR="${V1_GAME_DIR}/Data"
  fi
  if [ -n "$V1_GAME_DIR" ] && [ -d "${V1_GAME_DIR}/Content" ]; then
    V1_CONTENT_DIR="${V1_GAME_DIR}/Content"
  fi

  if [ -z "$V1_DATA_DIR" ]; then
    echo "Warning: could not locate v1.0.0 Data directory in '${V1_ZIP}'; mod enablement will be skipped for all builds." >&2
  fi
  if [ -z "$V1_CONTENT_DIR" ]; then
    echo "Warning: could not locate v1.0.0 Content directory in '${V1_ZIP}'; mod enablement will be skipped for all builds." >&2
  fi
fi

# --- download xdelta patches ---

TOTAL_KEYS="${#KEYS[@]}"
INDEX=0

for key in "${KEYS[@]}"; do
  INDEX=$((INDEX + 1))
  echo "Downloading artifact ${INDEX}/${TOTAL_KEYS}: ${key}..."
  if ! gh release download "$RELEASE" \
    --repo aitorciki/ladxhd-patcher \
    --pattern "${key}-*.xdelta" \
    --dir "$PATCH_DIR" \
    --clobber 2>/dev/null; then
    echo "Warning: no patch available for '${key}' in release '${RELEASE}', skipping." >&2
  fi
done

# --- apply patches ---

for key in "${KEYS[@]}"; do
  PATCH=$(find "$PATCH_DIR" -maxdepth 1 -name "${key}-*.xdelta" | head -1)
  if [ -z "$PATCH" ]; then
    echo "Warning: no patch found for '${key}', skipping." >&2
    continue
  fi

  PLATFORM_DIR="${OUT_DIR}/${key}"
  PATCHED_ZIP="${OUT_DIR}/${key}.zip"

  echo "Patching ${key}..."
  xdelta3 -d -s "$V1_ZIP" "$PATCH" "$PATCHED_ZIP"

  echo "Unpacking ${key}..."
  rm -rf "$PLATFORM_DIR"
  mkdir -p "$PLATFORM_DIR"
  unzip -qo "$PATCHED_ZIP" -d "$PLATFORM_DIR"
  rm -f "$PATCHED_ZIP"

  if [ "$ENABLE_MODS" = "true" ]; then
    enable_mods_for_key "$key" "$PLATFORM_DIR"
  fi

  USER_PLATFORM="$(platform_for_key "$key")"
  FINALIZE_FN="finalize_${USER_PLATFORM//-/_}"
  if declare -F "$FINALIZE_FN" >/dev/null; then
    echo "Finalizing ${key}..."
    "$FINALIZE_FN" "$PLATFORM_DIR" "$RELEASE"
  fi

  echo "Done: ${PLATFORM_DIR}/"
done

echo "All done. Output in ${OUT_DIR}/"
