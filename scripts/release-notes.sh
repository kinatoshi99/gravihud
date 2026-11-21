#!/usr/bin/env bash
set -euo pipefail

TAG="${1:?Usage: release-notes.sh <tag> <zip_file> <sha_file>}"
ZIP_FILE="${2:?Missing zip file path}"
SHA_FILE="${3:?Missing sha256 file path}"

ZIP_NAME="$(basename "${ZIP_FILE}")"
SHA_CONTENT="$(cat "${SHA_FILE}")"

cat << EOF
## GraviHUD ${TAG}

**100% offline, zero-port native macOS floating HUD for Google Antigravity.**

### Highlights
- **Zero Network & Zero Open Ports:** Verified statically in CI and at runtime via \`lsof\`.
- **Antigravity-Aware Auto-Visibility:** Appears automatically when Antigravity is focused (including **macOS Native Full-Screen Spaces**) and auto-hides when switching to other apps.
- **Compact Edge Card ↔ Full 4-Tab HUD:** 1-click collapse/expand, dock left/right, non-activating panel, automatic Light/Dark frosted glass, and bilingual **English / ไทย (Thai)** UI.
- **Universal macOS Binary (\`arm64\` + \`x86_64\`):** Native support for both Apple Silicon and Intel Macs (macOS 13.0+).

### Install Options

**Option 1 — Build locally from source (recommended, zero Gatekeeper prompts):**
\`\`\`bash
git clone https://github.com/kinatoshi99/gravihud.git
cd gravihud
./build.sh --install --run
\`\`\`

**Option 2 — Prebuilt Universal Archive:**
1. Download \`${ZIP_NAME}\` below and unzip it.
2. Verify checksum against \`SHA256SUMS.txt\`.
3. Because this free open-source build is ad-hoc signed (not Apple-notarized), clear the browser quarantine attribute before first launch:
   \`\`\`bash
   xattr -cr GraviHUD.app
   open GraviHUD.app
   \`\`\`

### Checksums (SHA-256)
\`\`\`text
${SHA_CONTENT}
\`\`\`
EOF
