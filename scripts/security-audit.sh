#!/usr/bin/env bash
# Reproducible static security audit for GraviHUD.
# Fails non-zero if any networking, shell execution, dynamic eval, or credential API
# is ever introduced into Sources/ or Resources/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PATTERN='https?://|wss?://|URLSession|NSURLConnection|CFNetwork|Network\.framework|Process\(|NSTask|popen|execve|SecItem|keychain|oauth|fetch\(|XMLHttpRequest|WebSocket|eval\(|new Function'

echo "==> Running static zero-network / zero-shell / zero-credential audit..."
if grep -rnE "${PATTERN}" "${ROOT_DIR}/Sources" "${ROOT_DIR}/Resources"; then
  echo ""
  echo "FAIL: Forbidden API or external URL pattern detected above."
  exit 1
fi

echo "PASS: Sources/ and Resources/ contain zero network, shell, eval, or credential APIs."
