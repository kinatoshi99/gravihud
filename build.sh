#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="GraviHUD"
APP_BUNDLE="${ROOT_DIR}/build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RES_DIR="${CONTENTS}/Resources"
BIN_PATH="${MACOS_DIR}/${APP_NAME}"

INSTALL_APPS=false
LAUNCH_AFTER=false
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL_APPS=true ;;
    --run)     LAUNCH_AFTER=true ;;
    -h|--help)
      echo "Usage: ./build.sh [--install] [--run]"
      echo "  --install  Copy built GraviHUD.app to /Applications"
      echo "  --run      Launch GraviHUD.app after building"
      exit 0
      ;;
  esac
done

echo "==> Building ${APP_NAME}.app (native macOS, zero dependencies, 100% offline)..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"

swiftc \
  -O \
  -parse-as-library \
  -framework AppKit \
  -framework Foundation \
  -framework WebKit \
  "${ROOT_DIR}/Sources/Models.swift" \
  "${ROOT_DIR}/Sources/Pricing.swift" \
  "${ROOT_DIR}/Sources/TranscriptParser.swift" \
  "${ROOT_DIR}/Sources/SettingsStore.swift" \
  "${ROOT_DIR}/Sources/WebUI.swift" \
  "${ROOT_DIR}/Sources/FloatingPanelController.swift" \
  "${ROOT_DIR}/Sources/AppMain.swift" \
  -o "${BIN_PATH}"

cp "${ROOT_DIR}/Resources/panel.html" "${RES_DIR}/panel.html"

cat > "${CONTENTS}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>GraviHUD</string>
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
  <string>1.0.0</string>
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
