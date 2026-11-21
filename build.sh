#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="GraviHUD"
VERSION="1.0.0"
APP_BUNDLE="${ROOT_DIR}/build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RES_DIR="${CONTENTS}/Resources"
BIN_PATH="${MACOS_DIR}/${APP_NAME}"

UNIVERSAL=false
INSTALL_APPS=false
LAUNCH_AFTER=false
CREATE_ZIP=false

for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=true ;;
    --install)   INSTALL_APPS=true ;;
    --run)       LAUNCH_AFTER=true ;;
    --zip)       CREATE_ZIP=true ;;
    -h|--help)
      echo "Usage: ./build.sh [--universal] [--install] [--run] [--zip]"
      echo "  --universal  Build a Universal macOS binary (arm64 + x86_64)"
      echo "  --install    Copy built GraviHUD.app to /Applications"
      echo "  --run        Launch GraviHUD.app after building"
      echo "  --zip        Create release .zip archive and SHA256SUMS.txt in build/"
      exit 0
      ;;
  esac
done

SOURCES=(
  "${ROOT_DIR}/Sources/Models.swift"
  "${ROOT_DIR}/Sources/Pricing.swift"
  "${ROOT_DIR}/Sources/TranscriptParser.swift"
  "${ROOT_DIR}/Sources/SettingsStore.swift"
  "${ROOT_DIR}/Sources/WebUI.swift"
  "${ROOT_DIR}/Sources/FloatingPanelController.swift"
  "${ROOT_DIR}/Sources/AppMain.swift"
)

COMMON_FLAGS=(
  -O
  -parse-as-library
  -framework AppKit
  -framework Foundation
  -framework WebKit
)

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"

if [ "${UNIVERSAL}" = true ]; then
  echo "==> Building ${APP_NAME}.app v${VERSION} (Universal: arm64 + x86_64, zero dependencies, 100% offline)..."
  TMP_BUILD="$(mktemp -d)"
  trap 'rm -rf "${TMP_BUILD}"' EXIT

  swiftc "${COMMON_FLAGS[@]}" -target arm64-apple-macos13.0 "${SOURCES[@]}" -o "${TMP_BUILD}/${APP_NAME}-arm64"
  swiftc "${COMMON_FLAGS[@]}" -target x86_64-apple-macos13.0 "${SOURCES[@]}" -o "${TMP_BUILD}/${APP_NAME}-x86_64"
  lipo -create "${TMP_BUILD}/${APP_NAME}-arm64" "${TMP_BUILD}/${APP_NAME}-x86_64" -output "${BIN_PATH}"
  ARCH_LABEL="universal"
else
  HOST_ARCH="$(uname -m)"
  echo "==> Building ${APP_NAME}.app v${VERSION} (${HOST_ARCH}, zero dependencies, 100% offline)..."
  swiftc "${COMMON_FLAGS[@]}" "${SOURCES[@]}" -o "${BIN_PATH}"
  ARCH_LABEL="${HOST_ARCH}"
fi

cp "${ROOT_DIR}/Resources/panel.html" "${RES_DIR}/panel.html"

# Generate crisp native macOS AppIcon.icns from pure CoreGraphics script
ICONSET_TMP="$(mktemp -d)/AppIcon.iconset"
swift "${ROOT_DIR}/scripts/generate-icon.swift" "${ICONSET_TMP}" >/dev/null
iconutil -c icns "${ICONSET_TMP}" -o "${RES_DIR}/AppIcon.icns"
rm -rf "$(dirname "${ICONSET_TMP}")"

cat > "${CONTENTS}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>GraviHUD</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>dev.kinatoshi99.gravihud</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>GraviHUD</string>
  <key>CFBundleDisplayName</key>
  <string>GraviHUD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "==> Build succeeded: ${APP_BUNDLE}"
lipo -info "${BIN_PATH}"

if [ "${CREATE_ZIP}" = true ]; then
  ZIP_NAME="${APP_NAME}-v${VERSION}-macos-${ARCH_LABEL}.zip"
  ZIP_PATH="${ROOT_DIR}/build/${ZIP_NAME}"
  rm -f "${ZIP_PATH}" "${ROOT_DIR}/build/SHA256SUMS.txt"
  ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"
  (cd "${ROOT_DIR}/build" && shasum -a 256 "${ZIP_NAME}" > SHA256SUMS.txt)
  echo "==> Packaged release archive: ${ZIP_PATH}"
  cat "${ROOT_DIR}/build/SHA256SUMS.txt"
fi

if [ "${INSTALL_APPS}" = true ]; then
  TARGET="/Applications/${APP_NAME}.app"
  echo "==> Installing to ${TARGET}..."
  rm -rf "${TARGET}"
  cp -R "${APP_BUNDLE}" "${TARGET}"
  echo "==> Installed: ${TARGET}"
  APP_BUNDLE="${TARGET}"
fi

if [ "${LAUNCH_AFTER}" = true ]; then
  echo "==> Launching ${APP_BUNDLE}..."
  open "${APP_BUNDLE}"
fi
