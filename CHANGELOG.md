# Changelog

All notable changes to **GraviHUD** are documented in this file.

## [1.0.1] - 2026-11-27

### Added
- **Strict auto-launch mode (`--keep-alive`)** in `scripts/install-login-item.sh` so macOS `launchd` automatically respawns GraviHUD if it exits unexpectedly.
- **Optional Antigravity lifecycle hook installer (`scripts/install-agy-hook.sh`)** registering zero-token `SessionStart` and `PreInvocation` hooks in `~/.gemini/config/hooks.json` so GraviHUD automatically launches and surfaces on every Antigravity session.
- **`--notify-ensure` IPC flag** (`dev.kinatoshi99.gravihud.ensure`) to unhide the floating panel on new chat sessions while strictly respecting the *Only Show with Antigravity* setting.

### Fixed
- Automatically reset manual panel hide state (`X` button) whenever Antigravity quits or relaunches so reopening Antigravity always brings the floating HUD back.

## [1.0.0] - 2026-11-21

### Added
- Native macOS floating HUD (`NSPanel` + `NSVisualEffectView`) with zero third-party dependencies.
- **100% Offline & Zero-Port architecture:** No `URLSession`, no `fetch()`, no local HTTP port, strict `WKWebView` CSP + navigation blocking, and automated static security audit (`scripts/security-audit.sh`).
- **Antigravity-aware auto-visibility:** Automatically surfaces over Antigravity (including macOS Native Full-Screen Spaces) and hides cleanly when switching to other apps, with a 1-click toggle to float over all apps.
- **Compact Edge Card ↔ Full 4-Tab HUD:** Overview, History (`Today / 7D / 30D / All` stacked trend chart), searchable Steps inspector, and Settings with built-in security summary.
- **Read-only transcript scanner** with `mtime + size` caching and torn-line recovery for live Antigravity sessions.
- **Bilingual EN / ไทย (Thai) UI** auto-detected from macOS system locale, plus Light/Dark native frosted glass sync.
- **Universal macOS binary (`arm64` + `x86_64`)** build support, native generated `AppIcon.icns`, optional LaunchAgent login helper, and GitHub Actions CI + Release workflows.
