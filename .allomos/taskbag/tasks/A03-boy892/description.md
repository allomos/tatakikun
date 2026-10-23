**Outcome.** Names that are no dictionary word still come out whole: Chinese names jieba lists as person names, and Japanese names built from a family name and a given name in the Mozc dictionary.

**Done means.** `tatakikun-cli --packs build/packs lixiangqin` shows 李香琴 and `ouki` shows 王暉 among the candidates; common words still come first (lixiang → 理想); engine tests pass.

**Notes.** Asked by the person on 2026-10-24.

## Evidence

- 2026-10-23, claude-names: v0.6.9 released 2026-10-24 on the person's request ('then release a new version with these changes'): https://github.com/allomos/tatakikun/releases/tag/v0.6.9 with pkg, APK and .sha256; APK passed scripts/test-android.sh on emulator-5554 (second run; first run failed once on the ai/愛 learning step); installed on this Mac (0.6.9). Do not tag or publish v0.6.9 again.
