**Outcome.** We know whether the Swift engine builds for Android with the Swift SDK for Android, and how much size it adds to an app.

**Done means.**
- TatakikunCore builds for Android arm64 as a shared library with the Swift SDK for Android on this Mac.
- The size of everything the app would ship (engine + Swift runtime + Foundation libraries) is measured and recorded under Evidence.
- A verdict: OK for option (a), or fails badly (then propose Rust per the person's decision).

**Notes.**
- The person approved installing Android tools on this Mac (2026-10-22); the Swift SDK for Android is part of this check.
- Running it on a device/emulator is part of A01-10, not this check.

**Evidence.**
- Tools: Swift 6.3.3 open-source toolchain (swift.org, Apple-notarized pkg, installed for this user in ~/Library/Developer/Toolchains), Swift SDK for Android 6.3.3 (checksum d160cc32…), Android NDK 28.2.13676358 (already installed). Xcode's Swift 6.4 has no matching Android SDK yet.
- `scripts/build-android.sh` builds `libTatakikunEngine.so` for arm64-v8a (aarch64-unknown-linux-android28) with FoundationEssentials only. The one fix needed: `memcmp` came through full Foundation; key comparison is now plain Swift.
- What an app ships for the engine (stripped, arm64): libswiftCore 6.58 MB, libFoundationEssentials 6.17 MB, libc++_shared 1.25 MB, libswift_RegexParser 0.93, libswift_Concurrency 0.85, libswift_StringProcessing 0.66, libdispatch 0.37, libTatakikunEngine 0.25, others 0.14: **17.2 MB installed, about 5.9 MB compressed** in the APK (zip -9).
- Full Foundation would add libFoundation + lib_FoundationICU + libFoundationInternationalization: 46 MB stripped (18 MB compressed), so FoundationEssentials (A02-mantle732) saves that.
- Not counted: the language packs (zh 21 MB, ja 44 MB, en 3 MB), and the Kotlin app itself. Not run on a device or emulator (A01-10).
- **Verdict: OK for option (a)** (Swift everywhere): it builds without changes beyond memcmp and the size is moderate.
