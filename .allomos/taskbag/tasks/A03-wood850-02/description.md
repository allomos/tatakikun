**Outcome.** Typing `ecole` gives école and `francais` gives français: accents, ç and œ come from plain letters.

**Done means.**
- `ecole` → école, `francais` → français, `coeur` → cœur, `ou` offers both où and ou.
- Common words rank first, by how often they are used.
- It is its own language pack, chosen in the installer and turned on or off in settings (A04-tuna688).
- Its candidates mix with English, Chinese and Japanese ones, and the raw letter string stays a candidate.
- Tests cover at least 50 common words and a few whole short phrases.
- Checked on macOS, Android and iOS.

**Notes.**
- Latin script, so this is mostly a word list with frequencies, plus matching letters without accents. It can share the accent matching with Spanish (A03-wood850-01).
- Part of A03-wood850 (five more languages, chosen by the person on 2026-10-23).
- **Open for the person:** the word list source and its licence (it must allow MIT redistribution), and how much the pack may add to the app size. Propose a source with its licence and size before building.
- **Approved by the approver (2026-10-25):** the word list sources and pack size in the handoff note's proposal (claude-loop3, 2026-10-25).

**Evidence.**
- Merged into master (be3dc4f). The fr pack (build/packs/fr, 1.3 MB, 50 000 words) is built like Spanish's (A03-wood850-01, WordConverter) from Common Voice's French sentences (wiki-1.fr.txt, wiki-2.fr.txt, sentence-collector.txt at commit f96d1c37, CC0; pinned with SHA-256 in `scripts/fetch-sources.sh`). Accents, ç and œ come from plain letters (ecole → école, francais → français, coeur → cœur); `ou` offers ou and où. A word with an elided start counts as itself and as the word after the apostrophe: cest → c'est, lecole → l'école, aujourdhui → aujourd'hui, ecole → école. This also rebuilt the Spanish pack (a few more words from apostrophes; nothing else changed).
- A new candidate kind FR (`.french`); Français in the input menu (macOS), Input languages (iOS) and the language dialog (Android), and in the installer (checked by default) and `scripts/install.sh`.
- `FrenchTests` (about 80 common words, 6 short phrases word by word, accents, elisions, mixing, turning off); `swift test`: 97 tests, 0 failures; with French on, yinhang 银行, watashi 私, hello, woaini 我爱你, cancion canción stay first.
- Android (Pixel_7_API_34_b emulator): `scripts/test-android.sh` passes, with `francais SPACE` → `français `. iOS (iPhone 16 Pro simulator): UI test `testFrenchAccentsFromPlainLetters` (francais → français, coeur → cœur) and all 15 UI tests pass. macOS: the input method builds and `tatakikun-cli --packs build/packs` shows the candidates; not reinstalled here (it disconnects the person's Electron apps), and the installer was not rebuilt.
