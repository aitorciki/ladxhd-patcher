#!/usr/bin/env bash

set -euo pipefail

# Download and apply release xdelta patches against a v1.0.0 zip.

ALL_KEYS=(
    windows-dx windows-gl
    linux-x64-standalone linux-arm64-standalone linux-x64-appimage linux-arm64-appimage
    macos-arm64-game macos-arm64-launcher macos-x64-game macos-x64-launcher
    android
)

VALID_PLATFORMS=(
    windows-dx windows-gl
    linux-x64 linux-arm64 linux-x64-appimage linux-arm64-appimage
    macos-arm64 macos-arm64-launcher macos-x64 macos-x64-launcher
    android
)

SCRIPT_NAME="$(basename "$0")"

print_usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} --source <v1.zip> [--release <release>] [--platform <platform>]

Download and apply release xdelta patches against a v1.0.0 zip.

Flags:
  -s, --source     Path to the v1.0.0 zip archive (required)
  -r, --release    Release to download patches from (default: latest)
  -p, --platform   Platform to patch (default: current host platform)
  -h, --help       Show this help message

Valid releases:
  latest                 Resolve the latest GitHub release tag
  nightly                Download patches from the nightly release
  <github-release-tag>   Any explicit GitHub release tag

Valid platforms:
  all
  windows-dx
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
  Omitting --platform selects the current host platform
  On Windows, the detected default is windows-dx
  linux-x64 maps internally to linux-x64-standalone
  linux-arm64 maps internally to linux-arm64-standalone
  macos-arm64 maps internally to macos-arm64-game
  macos-x64 maps internally to macos-x64-game
  Output is written to ./patched/<platform>/
  Downloaded patches are stored in a temporary directory and cleaned up automatically
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
        printf '%s\n' "windows-dx"
        ;;
    *)
        return 1
        ;;
    esac
}

# --- argument parsing ---

V1_ZIP=""
RELEASE="latest"
PLATFORM=""

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
        PLATFORM="$2"
        shift 2
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
    print_usage >&2
    exit 1
fi

if [ -z "$PLATFORM" ]; then
    if ! PLATFORM="$(detect_host_platform)"; then
        echo "Error: could not detect a supported host platform from $(uname -s)/$(uname -m)." >&2
        echo "Specify one explicitly with '${SCRIPT_NAME} --platform <platform>' or run '${SCRIPT_NAME} --help'." >&2
        exit 1
    fi
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

if [ "$PLATFORM" = "all" ]; then
    KEYS=("${ALL_KEYS[@]}")
else
    VALID=false
    for valid_platform in "${VALID_PLATFORMS[@]}"; do
        if [ "$PLATFORM" = "$valid_platform" ]; then
            VALID=true
            break
        fi
    done

    if [ "$VALID" != "true" ]; then
        echo "Error: unsupported platform '$PLATFORM'." >&2
        echo "Supported platforms: all ${VALID_PLATFORMS[*]}" >&2
        echo "Run '${SCRIPT_NAME} --help' for usage." >&2
        exit 1
    fi

    case "$PLATFORM" in
    linux-x64) KEYS=("linux-x64-standalone") ;;
    linux-arm64) KEYS=("linux-arm64-standalone") ;;
    macos-arm64) KEYS=("macos-arm64-game") ;;
    macos-x64) KEYS=("macos-x64-game") ;;
    *) KEYS=("$PLATFORM") ;;
    esac
fi

# --- resolve release tag ---

if [ "$RELEASE" = "latest" ]; then
    RELEASE=$(gh release view --repo aitorciki/ladxhd-patcher --json tagName --jq '.tagName')
    echo "Resolved latest release: $RELEASE"
fi

if [ "$PLATFORM" = "all" ]; then
    echo "Preparing patches for release '${RELEASE}' on all platforms."
elif [ "$PLATFORM" != "${KEYS[0]}" ]; then
    echo "Preparing patches for release '${RELEASE}' on platform '${PLATFORM}' (internal key: '${KEYS[0]}')."
else
    echo "Preparing patches for release '${RELEASE}' on platform '${PLATFORM}'."
fi

OUT_DIR="patched"
PATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/patch-release.XXXXXX")"
mkdir -p "$OUT_DIR"

cleanup() {
    rm -rf "$PATCH_DIR"
}

trap cleanup EXIT

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

    echo "Done: ${PLATFORM_DIR}/"
done

echo "All done. Output in ${OUT_DIR}/"
