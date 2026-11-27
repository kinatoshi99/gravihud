#!/usr/bin/env bash
# Optional helper: registers (or removes) GraviHUD as a per-user macOS LaunchAgent
# so it starts quietly in the Menu Bar on login and auto-appears when Antigravity is focused.
set -euo pipefail

LABEL="dev.kinatoshi99.gravihud"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

KEEP_ALIVE=false
for arg in "$@"; do
  case "$arg" in
    --uninstall)
      launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || true
      rm -f "${PLIST_PATH}"
      echo "Removed LaunchAgent: ${PLIST_PATH}"
      exit 0
      ;;
    --keep-alive|--strict)
      KEEP_ALIVE=true
      ;;
  esac
done

APP_BIN="/Applications/GraviHUD.app/Contents/MacOS/GraviHUD"
if [ ! -x "${APP_BIN}" ]; then
  APP_BIN="${ROOT_DIR}/build/GraviHUD.app/Contents/MacOS/GraviHUD"
fi

if [ ! -x "${APP_BIN}" ]; then
  echo "Error: GraviHUD.app not found. Run ./build.sh (or ./build.sh --install) first." >&2
  exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"
if [ "${KEEP_ALIVE}" = true ]; then
  KEEP_ALIVE_XML="  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>5</integer>"
else
  KEEP_ALIVE_XML="  <key>KeepAlive</key>
  <false/>"
fi

cat > "${PLIST_PATH}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${APP_BIN}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
${KEEP_ALIVE_XML}
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
echo "Installed & started LaunchAgent: ${PLIST_PATH}"
echo "Target binary: ${APP_BIN}"
echo "To remove later: ./scripts/install-login-item.sh --uninstall"
