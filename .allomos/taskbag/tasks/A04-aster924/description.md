**Outcome.** After a fresh install, only Chinese, Japanese and English give candidates; the other installed language packs (Arabic, Bengali, Spanish, French, Hindi) start turned off, and the user turns them on in the input menu (Mac) or settings (phones).

**Done means.**
- Mac: with no saved choice (`languagesOff` unset), the input menu shows only 中文, 日本語 and English checked; typing `houxuan` then `2` picks the second candidate even though the Arabic pack is installed.
- Android and iOS: a fresh install shows the same three on in settings.
- A user who already chose languages keeps their choice (a saved setting is not reset).
- If none of zh, ja, en is installed, whatever is installed stays on, so at least one language gives candidates.

**Notes.**
- Asked by the person on 2026-10-26, after learning that an Arabic pack that is on makes a digit after some letters part of an Arabizi word (`Engine.takesDigit`) instead of choosing a candidate.
- Mac: the default lives in `TatakikunApp.turnedOff` (`Sources/Tatakikun/main.swift`, `languagesOff`). Phones: the language settings from A04-tuna688.
