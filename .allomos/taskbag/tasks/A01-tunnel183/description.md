**Outcome.** Holding a key with a corner symbol shows it twice in the popup, half-width and full-width (for example ? and ？); sliding the finger onto one and lifting types exactly that one, whatever the language before the cursor.

**Done means.** On the emulator: hold a, lift → @; hold a, slide right, lift → ＠, also right after Chinese text; a tap still types the letter.

**Notes.** Asked by the person on 2026-10-23. Symbols without a full-width form (、) show one choice.

## Evidence

- 2026-10-23, claude-android-landscape: Released in v0.6.8 (2026-10-23), approved by the person's line "when finished, call alm guide GitHub release" in the conversation, 2026-10-23. https://github.com/allomos/tatakikun/releases/tag/v0.6.8 with Tatakikun-0.6.8.pkg (sha256 5f85b1a183d5657c52ad7d141d17046bdfa445c282708344fc461f90eb515473), Tatakikun-0.6.8-android.apk (sha256 b0deb561ccffaa25da23a1b204060d23b5a33a2fd71831ffa7f0d034d314ad81, signer 05d10759…) and both .sha256 files; release APK passed scripts/test-android.sh on Pixel_7_API_34_b (9/9); pkg downloaded, checksum OK, installed here, version 0.6.8 running. No CI release workflow (Mac build is local).
