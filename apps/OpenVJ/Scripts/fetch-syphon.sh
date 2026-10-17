#!/bin/bash
# Builds Syphon.xcframework from Syphon-Framework (macOS arm64).
set -euo pipefail

SYPHON_REPO="https://github.com/Syphon/Syphon-Framework.git"
PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="${PKG_DIR}/Vendor"
WORK_DIR="${VENDOR_DIR}/.syphon-build"
OUT="${VENDOR_DIR}/Syphon.xcframework"

command -v xcodebuild >/dev/null || { echo "error: xcodebuild required" >&2; exit 1; }
command -v git >/dev/null || { echo "error: git required" >&2; exit 1; }

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

echo "==> clone Syphon-Framework"
git clone --depth 1 "${SYPHON_REPO}" "${WORK_DIR}/Syphon-Framework"

SRC="${WORK_DIR}/Syphon-Framework"
DERIVED="${WORK_DIR}/DerivedData"

echo "==> build Syphon.framework (Release, arm64)"
xcodebuild \
  -project "${SRC}/Syphon.xcodeproj" \
  -scheme Syphon \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${DERIVED}" \
  ONLY_ACTIVE_ARCH=YES \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  > /dev/null

FRAMEWORK="${DERIVED}/Build/Products/Release/Syphon.framework"
if [ ! -d "${FRAMEWORK}" ]; then
  echo "error: missing ${FRAMEWORK}" >&2
  exit 1
fi

echo "==> create xcframework"
rm -rf "${OUT}"
xcodebuild -create-xcframework \
  -framework "${FRAMEWORK}" \
  -output "${OUT}" \
  > /dev/null

rm -rf "${WORK_DIR}"
echo "==> done: ${OUT}"
