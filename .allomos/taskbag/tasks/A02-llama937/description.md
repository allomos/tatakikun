**Outcome.** Phone QWERTY keys are small; when a letter was typed on a key next to the intended one, the candidates also offer the words the intended letters would give, a little lower and marked as not typed exactly.

**Done means.** On Android and iOS, typing with one neighbouring-key slip (nihai, xiexir, arigatp) still offers 你好, 谢谢, ありがとう in the bar; exact matches stay first; the Mac keeps its behaviour; engine tests cover it.

**Notes.** Asked by the person on 2026-10-24.

## Evidence

- 2026-10-23, claude-typos: v0.6.9 released 2026-10-24 on the person's request ('then release a new version with these changes'): https://github.com/allomos/tatakikun/releases/tag/v0.6.9 with pkg, APK and .sha256; APK passed scripts/test-android.sh on emulator-5554 (second run; first run failed once on the ai/愛 learning step); installed on this Mac (0.6.9). Do not tag or publish v0.6.9 again.
