#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d)
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -module-cache-path "$CHECK_DIR/cache" InvisibleViolin/GestureInstrument.swift Tests/main.swift -o "$CHECK_DIR/gestures"
"$CHECK_DIR/gestures"
clang -std=c11 -I InvisibleViolin InvisibleViolin/ViolinDSP.c Tests/audio_test.c -o "$CHECK_DIR/audio"
"$CHECK_DIR/audio"
