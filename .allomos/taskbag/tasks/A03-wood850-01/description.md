**Outcome.** Typing `cancion` gives canción and `nino` gives niño: accents and ñ come from plain letters, and words typed with the accents also work.

**Done means.**
- `cancion` → canción, `nino` → niño, `esta` offers both está and esta.
- Common words rank first, by how often they are used.
- It is its own language pack, chosen in the installer and turned on or off in settings (A04-tuna688).
- Its candidates mix with English, Chinese and Japanese ones, and the raw letter string stays a candidate.
- Tests cover at least 50 common words and a few whole short phrases.
- Checked on macOS, Android and iOS.

**Notes.**
- Latin script, so this is mostly a word list with frequencies, plus matching letters without accents.
- Part of A03-wood850 (five more languages, chosen by the person on 2026-10-23).
- **Open for the person:** the word list source and its licence (it must allow MIT redistribution), and how much the pack may add to the app size. Propose a source with its licence and size before building.
- **Approved by the approver (2026-10-25):** the word list sources and pack size in the handoff note's proposal (claude-loop3, 2026-10-25).

**Evidence.**
- Merged into master (a5ba7ee). The es pack (build/packs/es, 1.25 MB, 50 000 words) is built by `tatakikun-dictgen pack es` from Common Voice's Spanish sentences (wiki.es.txt and sentence-collector.txt at commit f96d1c37, CC0; pinned with SHA-256 in `scripts/fetch-sources.sh`): words seen at least 3 times, the 50 000 most used, each keyed without accents (WordConverter.key) and cheaper the more it is used (40 + 5.5 ln rank, +10 for three letters or fewer, on the English pack's scale). A name keeps its capital (Madrid); other words are lowercase.
- Engine: a new candidate kind ES (`.spanish`) from `WordConverter`, the shared part for languages typed word by word; words typed with their accents are found too; completions (cancio → canción…). It is a language like the others in the input menu (macOS), Input languages (iOS) and the language dialog (Android), and in the installer (checked by default) and `scripts/install.sh`.
- `SpanishTests` (95 common words, 5 short phrases word by word, accents, mixing, turning off); `swift test`: 93 tests, 0 failures. With Spanish on, yinhang 银行, watashi 私, hello, woaini 我爱你, arigatou ありがとう stay first.
- Android (Pixel_7_API_34_b emulator): `scripts/test-android.sh` passes, with `cancion SPACE` → `canción ` and `manana SPACE` → `mañana `. iOS (iPhone 16 Pro simulator): UI test `testSpanishAccentsFromPlainLetters` (cancion → canción, nino → niño in the Try it field) and all 14 UI tests pass. macOS: the input method builds and `tatakikun-cli --packs build/packs` shows the candidates (cancion → canción, esta → está esta ésta); not reinstalled here (it disconnects the person's Electron apps), and the installer was not rebuilt.
- A word Spanish shares with English (con, me) comes once, tagged EN. Wikipedia sentences make the list lean to written words; some names keep their capital (Nino next to niño).
