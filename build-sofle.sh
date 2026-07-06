#!/usr/bin/env bash
#
# Initializes the west workspace (if needed) and builds firmware for both
# halves of the sofle shield. Run from inside the devcontainer.
#
# Usage: ./build-sofle.sh [-c|--clean] [-r|--reset]
#   -c, --clean   Wipe existing build output and do a pristine rebuild
#   -r, --reset   Also build the settings_reset firmware

set -euo pipefail

BOARD="nice_nano"
SHIELD="sofle"
BUILD_DIR="build"
CLEAN=0
RESET=0

usage() {
    echo "Usage: $0 [-c|--clean] [-r|--reset]"
    echo "  -c, --clean   Wipe existing build output and do a pristine rebuild"
    echo "  -r, --reset   Also build the settings_reset firmware"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean)
            CLEAN=1
            shift
            ;;
        -r|--reset)
            RESET=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -d .west ]]; then
    echo "==> Initializing west workspace"
    west init -l app
fi

echo "==> Updating west modules"
west update --fetch-opt=--filter=tree:0

echo "==> Exporting Zephyr CMake package"
west zephyr-export

PRISTINE_ARGS=()
if [[ "$CLEAN" -eq 1 ]]; then
    echo "==> Clean requested, removing previous build output"
    rm -rf "$BUILD_DIR/left" "$BUILD_DIR/right" "$BUILD_DIR/settings_reset"
    PRISTINE_ARGS=(-p)
fi

SHIELD_DIR="${SCRIPT_DIR}/app/boards/shields/${SHIELD}"

# The sofle shield predates Zephyr's YAML shield format, and its .conf
# fragments aren't reliably auto-discovered by the current Zephyr version's
# shield config merging. Pass them explicitly so settings like
# CONFIG_ZMK_POINTING actually make it into the build.
LEFT_CONF_FILES="${SHIELD_DIR}/${SHIELD}.conf;${SHIELD_DIR}/${SHIELD}_left.conf"
RIGHT_CONF_FILES="${SHIELD_DIR}/${SHIELD}.conf;${SHIELD_DIR}/${SHIELD}_right.conf"

echo "==> Building left half (${SHIELD}_left)"
west build -s app -d "$BUILD_DIR/left" "${PRISTINE_ARGS[@]}" -b "$BOARD" -- -DSHIELD="${SHIELD}_left" -DEXTRA_CONF_FILE="$LEFT_CONF_FILES"

echo "==> Building right half (${SHIELD}_right)"
west build -s app -d "$BUILD_DIR/right" "${PRISTINE_ARGS[@]}" -b "$BOARD" -- -DSHIELD="${SHIELD}_right" -DEXTRA_CONF_FILE="$RIGHT_CONF_FILES"

if [[ "$RESET" -eq 1 ]]; then
    echo "==> Building settings_reset firmware"
    west build -s app -d "$BUILD_DIR/settings_reset" "${PRISTINE_ARGS[@]}" -b "$BOARD" -- -DSHIELD=settings_reset
fi

echo "==> Done"
echo "Left firmware:  $BUILD_DIR/left/zephyr/zmk.uf2"
echo "Right firmware: $BUILD_DIR/right/zephyr/zmk.uf2"
if [[ "$RESET" -eq 1 ]]; then
    echo "Reset firmware: $BUILD_DIR/settings_reset/zephyr/zmk.uf2"
fi
