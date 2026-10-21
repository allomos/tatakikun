**Outcome.** The engine (TatakikunCore) needs only FoundationEssentials, not the full Foundation with ICU, on platforms that have it (Linux, Windows, Android), so the Android build is about 40 MB smaller. macOS and iOS keep working the same.

**Done means.**
- No engine file needs the full Foundation where FoundationEssentials exists (`#if canImport(FoundationEssentials)`); NSString path calls are replaced by URL.
- `swift build` and `swift test` pass on macOS; the iOS keyboard still builds.

**Notes.**
- Decided by the person 2026-10-22: stay with Swift everywhere (option a), switch to FoundationEssentials, then check Android and Windows builds; if either fails badly, switch to Rust for all platforms.
- The English spell checker (English.swift) is Apple-only; other platforms get it without spell suggestions for now.
