# Security Model & Self-Audit Guide

GraviHUD is designed from first principles to be **100% offline, read-only, and non-invasive**. You do not have to take our word for it — every claim below can be verified locally in seconds.

## Hard Guarantees

1. **Zero Network & Zero Open Ports**
   - No `URLSession`, `CFNetwork`, `Network.framework`, `fetch()`, `XMLHttpRequest`, or `WebSocket`.
   - No localhost HTTP server or listening TCP/UDP socket.
   - The UI runs inside a `WKWebView` with a `nonPersistent()` data store, a strict `Content-Security-Policy` (`default-src 'none'; connect-src 'none'`), and a `WKNavigationDelegate` that rejects every external or file URL navigation.
   - All Swift ↔ UI messages stay strictly in-memory via `WKScriptMessageHandler`.

2. **Zero Antigravity Injection or Modification**
   - GraviHUD never enables Chrome DevTools Protocol (CDP), never modifies desktop shortcuts or app bundles, never injects scripts into Electron windows, and never invokes undocumented internal RPCs.
   - Auto-show/auto-hide uses only macOS's public `NSWorkspace` frontmost-application API (`com.google.antigravity`).

3. **Zero Special macOS Privacy Permissions**
   - Requires **no** Accessibility permission.
   - Requires **no** Screen Recording permission.
   - Never reads macOS Keychain, OAuth tokens, cookies, or Google account credentials.

4. **Strict File Boundaries**
   - **Read-only:** `~/.gemini/antigravity/brain/<uuid>/.system_generated/logs/transcript.jsonl`
   - **Write (UI preferences only):** `~/Library/Application Support/GraviHUD/settings.json`

## Verify Yourself

### 1. Static Source Audit (automated in GitHub Actions CI on every push/PR)

```bash
./scripts/security-audit.sh
```

### 2. Runtime Socket Verification (must output nothing)

```bash
PID=$(pgrep -x GraviHUD | head -n 1)
lsof -nP -i -a -p "$PID"
```

## Reporting a Vulnerability

If you discover a security or privacy issue, please open a private security advisory on GitHub or report it directly to the maintainer rather than posting exploit details publicly.
