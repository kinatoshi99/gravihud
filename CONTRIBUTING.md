# Contributing to GraviHUD

Contributions are welcome! Before opening a Pull Request, please keep these core design rules in mind:

## Non-Negotiable Principles

1. **Stay 100% Offline & Zero-Port:** Never add outbound HTTP calls, auto-updaters, telemetry, analytics, CDNs, remote fonts, or local HTTP servers. CI runs `./scripts/security-audit.sh` on every PR and will reject forbidden APIs.
2. **Zero Third-Party Dependencies:** GraviHUD compiles directly with macOS's built-in `swiftc` using only system frameworks (`AppKit`, `Foundation`, `WebKit`).
3. **Never Hack or Inject Into Antigravity:** Do not add CDP/remote-debugging hooks, Electron window injection, Keychain/credential reads, or undocumented internal RPC calls.
4. **Keep Read-Only Boundaries Strict:** Only read documented local `transcript.jsonl` files and write preferences solely to `~/Library/Application Support/GraviHUD/settings.json`.

## Local Development Workflow

```bash
# 1. Run static security audit
./scripts/security-audit.sh

# 2. Run Swift unit tests
swiftc -parse-as-library \
  Sources/Models.swift \
  Sources/Pricing.swift \
  Sources/TranscriptParser.swift \
  Sources/SettingsStore.swift \
  Tests/run_tests.swift \
  -o /tmp/gravihud_tests && /tmp/gravihud_tests && rm -f /tmp/gravihud_tests

# 3. Build and test the macOS app bundle
./build.sh --run
```
