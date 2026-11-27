#!/usr/bin/env bash
# Optional helper: registers (or removes) an Antigravity global lifecycle hook
# (~/.gemini/config/hooks.json) so GraviHUD automatically launches and surfaces
# whenever an Antigravity session starts or runs a prompt, without injecting tokens.
set -euo pipefail

CONFIG_DIR="${HOME}/.gemini/config"
SCRIPTS_DIR="${CONFIG_DIR}/scripts"
HOOK_SCRIPT="${SCRIPTS_DIR}/gravihud-ensure.py"
HOOKS_JSON="${CONFIG_DIR}/hooks.json"

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "${HOOK_SCRIPT}"
  if [ -f "${HOOKS_JSON}" ]; then
    HOOKS_JSON_PATH="${HOOKS_JSON}" /usr/bin/python3 - << 'PYEOF'
import json
import os
from pathlib import Path

p = Path(os.environ["HOOKS_JSON_PATH"])
try:
    data = json.loads(p.read_text(encoding="utf-8"))
    if isinstance(data, dict) and "gravihud-auto-open" in data:
        del data["gravihud-auto-open"]
        p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
except Exception:
    pass
PYEOF
  fi
  echo "Removed Antigravity hook: gravihud-auto-open (${HOOKS_JSON})"
  exit 0
fi

mkdir -p "${SCRIPTS_DIR}"

cat > "${HOOK_SCRIPT}" << 'PYEOF'
#!/usr/bin/python3
"""Antigravity lifecycle hook to ensure GraviHUD is running and visible whenever AGY is used."""

import subprocess
import sys
from pathlib import Path


def resolve_app_bundle():
    candidates = [
        Path("/Applications/GraviHUD.app"),
        Path.home() / "Applications" / "GraviHUD.app",
    ]
    for candidate in candidates:
        if (candidate / "Contents" / "MacOS" / "GraviHUD").is_file():
            return candidate
    return None


def is_gravihud_running():
    res = subprocess.run(
        ["/usr/bin/pgrep", "-x", "GraviHUD"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=2,
        check=False,
    )
    return res.returncode == 0


def ensure_gravihud(unhide):
    app_bundle = resolve_app_bundle()
    if app_bundle is None:
        return

    if not is_gravihud_running():
        subprocess.run(
            ["/usr/bin/open", "-g", str(app_bundle)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
            timeout=3,
            check=False,
        )
        return

    if unhide:
        app_bin = app_bundle / "Contents" / "MacOS" / "GraviHUD"
        subprocess.run(
            [str(app_bin), "--notify-ensure"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
            timeout=2,
            check=False,
        )


def main():
    try:
        sys.stdin.read()
    except Exception:
        pass

    unhide = "--unhide" in sys.argv[1:]
    try:
        ensure_gravihud(unhide=unhide)
    except Exception:
        pass

    print("{}")


if __name__ == "__main__":
    main()
PYEOF

chmod +x "${HOOK_SCRIPT}"

HOOKS_JSON_PATH="${HOOKS_JSON}" /usr/bin/python3 - << 'PYEOF'
import json
import os
from pathlib import Path

p = Path(os.environ["HOOKS_JSON_PATH"])
data = {}
if p.is_file():
    try:
        loaded = json.loads(p.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {}

data["gravihud-auto-open"] = {
    "SessionStart": [
        {
            "type": "command",
            "command": "/usr/bin/python3 ./scripts/gravihud-ensure.py --unhide",
            "timeout": 5,
        }
    ],
    "PreInvocation": [
        {
            "type": "command",
            "command": "/usr/bin/python3 ./scripts/gravihud-ensure.py",
            "timeout": 5,
        }
    ],
}

p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PYEOF

echo "Installed Antigravity lifecycle hook: ${HOOKS_JSON} (gravihud-auto-open)"
echo "Helper script: ${HOOK_SCRIPT}"
echo "Note: Ensure GraviHUD.app is installed in /Applications (./build.sh --install)."
echo "To remove later: ./scripts/install-agy-hook.sh --uninstall"
