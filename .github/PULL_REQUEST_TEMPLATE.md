## Summary
Describe what this PR changes and why.

## Security & Privacy Checklist
- [ ] `./scripts/security-audit.sh` passes with zero forbidden APIs or external URLs.
- [ ] No outbound network requests, no local HTTP servers, no auto-updaters.
- [ ] No Antigravity injection, CDP hooks, Keychain reads, or undocumented RPCs.
- [ ] All Swift unit tests (`Tests/run_tests.swift`) pass.
- [ ] `./build.sh` compiles cleanly on macOS.
