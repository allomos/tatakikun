**Outcome.** A rare kanji or character read the same way as what was typed is in the expanded list, not cut off after the 40 most common.

**Done means.** `tatakikun-cli --packs build/packs --more 300 ki` lists 暉; engine tests pass.

**Notes.** Asked by the person on 2026-10-24.

## Evidence

- 2026-10-24, claude-ki: v0.6.10 released 2026-10-24 on the person's request ('Release all fixes as v0.6.10'): https://github.com/allomos/tatakikun/releases/tag/v0.6.10 (tag at 8c3e4ef; also ships A04-quail228, A04-ship843 and the Android part of A04-cell054), pkg, APK and .sha256; APK passed scripts/test-android.sh twice on emulator-5554; installed on this Mac (0.6.10). Do not tag or publish v0.6.10 again.
