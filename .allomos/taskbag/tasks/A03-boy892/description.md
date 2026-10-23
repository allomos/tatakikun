**Outcome.** Names that are no dictionary word still come out whole: Chinese names jieba lists as person names, and Japanese names built from a family name and a given name in the Mozc dictionary.

**Done means.** `tatakikun-cli --packs build/packs lixiangqin` shows 李香琴 and `ouki` shows 王暉 among the candidates; common words still come first (lixiang → 理想); engine tests pass.

**Notes.** Asked by the person on 2026-10-24.
