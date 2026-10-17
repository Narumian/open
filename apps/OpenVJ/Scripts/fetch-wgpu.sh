#!/bin/bash
# Fetches wgpu-native and builds CWGPU.xcframework (macOS arm64 only).
set -euo pipefail

WGPU_VERSION="v29.0.1.1"
BASE_URL="https://github.com/gfx-rs/wgpu-native/releases/download/${WGPU_VERSION}"
PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="${PKG_DIR}/Vendor"
WORK_DIR="${VENDOR_DIR}/.download"
OUT="${VENDOR_DIR}/CWGPU.xcframework"

log()  { printf '==> %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1 }

command -v xcodebuild >/dev/null || fail "xcodebuild required"
command -v curl >/dev/null || fail "curl required"
command -v unzip >/dev/null || fail "unzip required"

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

write_module_headers() {
  local headers_dir="$1"
  mkdir -p "${headers_dir}"
  cat > "${headers_dir}/CWGPU.h" <<'EOF'
#pragma once
#include "webgpu.h"
#include "wgpu.h"
EOF
  cat > "${headers_dir}/module.modulemap" <<'EOF'
module CWGPU {
    header "CWGPU.h"
    export *
}
EOF
}

slice="macos-arm64"
zip="wgpu-macos-aarch64-release.zip"
dir="${WORK_DIR}/${slice}"
log "fetch ${slice}"
mkdir -p "${dir}"
curl -fSL --retry 3 -o "${dir}/wgpu.zip" "${BASE_URL}/${zip}"
unzip -q -o "${dir}/wgpu.zip" -d "${dir}"
[ -f "${dir}/lib/libwgpu_native.a" ] || fail "missing libwgpu_native.a"

headers="${dir}/Headers"
mkdir -p "${headers}"
cp "${dir}/include/webgpu/webgpu.h" "${dir}/include/webgpu/wgpu.h" "${headers}/"
write_module_headers "${headers}"

log "create xcframework"
rm -rf "${OUT}"
xcodebuild -create-xcframework \
  -library "${dir}/lib/libwgpu_native.a" -headers "${headers}" \
  -output "${OUT}" >/dev/null

rm -rf "${WORK_DIR}"
log "done: ${OUT} (${WGPU_VERSION})"
