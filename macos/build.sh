#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
CACHE="$HERE/.headers"
mkdir -p "$BUILD" "$CACHE"

echo "==> building launcher.node (V8 version dispatcher)"
clang -bundle -undefined dynamic_lookup -o "$BUILD/launcher.node" "$HERE/launcher/dispatch.c"

build_injector() {
    local electron_version="$1"
    local headers_dir="$CACHE/node-v${electron_version}"
    local tarball="$CACHE/node-v${electron_version}-headers.tar.gz"

    if [ ! -d "$headers_dir/include/node" ]; then
        echo "==> downloading Electron ${electron_version} headers"
        curl -fL --retry 3 -o "$tarball" \
            "https://artifacts.electronjs.org/headers/dist/v${electron_version}/node-v${electron_version}-headers.tar.gz"
        mkdir -p "$headers_dir"
        tar xzf "$tarball" -C "$headers_dir" --strip-components=1
    fi

    local v8_major
    v8_major="$(awk '/^#define V8_MAJOR_VERSION/ {print $3}' "$headers_dir/include/node/v8-version.h")"
    echo "==> building ll-inject-v8-${v8_major}.node (Electron ${electron_version})"
    clang++ -std=c++20 -bundle -undefined dynamic_lookup -fobjc-arc -framework Foundation \
        -I "$headers_dir/include/node" \
        -o "$BUILD/ll-inject-v8-${v8_major}.node" \
        "$HERE/launcher/inject.mm"
}

# QQ 6.9.x base -> Electron 34 / V8 13
build_injector 34.0.0
# QQ 7.x hot update -> Electron 40 / V8 14
build_injector 40.0.0

echo "==> done: $BUILD"
ls -la "$BUILD"
