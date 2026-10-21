**Outcome.** We know whether the Swift engine builds for Android with the Swift SDK for Android, and how much size it adds to an app.

**Done means.**
- TatakikunCore builds for Android arm64 as a shared library with the Swift SDK for Android on this Mac.
- The size of everything the app would ship (engine + Swift runtime + Foundation libraries) is measured and recorded under Evidence.
- A verdict: OK for option (a), or fails badly (then propose Rust per the person's decision).

**Notes.**
- The person approved installing Android tools on this Mac (2026-10-22); the Swift SDK for Android is part of this check.
- Running it on a device/emulator is part of A01-10, not this check.
