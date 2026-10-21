**Outcome.** When the user mistypes pinyin by swapping neighbouring letters, as in `zhogn` for `zhong`, Tatakikun still offers the Chinese candidates for the intended pinyin (中, 种, 重 …).

**Done means.**
- Typing `zhogn` shows the candidates of `zhong`; the same works inside longer input (e.g. `zhognguo` → 中国).
- Input that is already valid pinyin keeps its exact-match candidates first; corrected candidates come after them.
- The raw letter string stays in the candidates (A02-03).
- Unit tests cover swapped letters alone and inside longer input, and show valid input is unchanged.

**Notes.**
- This is typo correction (letters typed in the wrong order), **not** fuzzy pinyin (z/zh, c/ch, s/sh, n/ng, l/n …); fuzzy pinyin is out of scope.
- Related: A02-04 (partial matches and English spelling suggestions), A02-01 (pinyin splitting).
- Routine choices for whoever works it (record with `alm ai-decided`): which other typo kinds to cover beyond swapped neighbours (default: swapped neighbours only), and how far corrected candidates rank below exact ones.
