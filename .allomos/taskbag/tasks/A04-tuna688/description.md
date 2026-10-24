**Outcome.** In Tatakikun's settings, the user turns each input language on or off. Only the languages that are on give candidates, and a change works at once, without reinstalling.

**Done means.**
- The settings list every installed language with an on/off switch, on macOS, Android and iOS.
- With a language off, typing gives no candidates in it. For example, with Japanese off, `watashi` gives no わたし or 私. Turn it back on and the candidates come back.
- The choice is kept after the keyboard or the app restarts.
- At least one language always stays on: you can't turn off the last one.

**Notes.**
- Today, macOS picks languages only when installing (A04-05), and the engine works from the installed packs (A02-07). This task adds turning them on and off afterwards.
- **iOS, decided by the approver (2026-10-25, same decision as the iPad Ctrl key in A04-cell054):** turn on Full Access (`RequestsOpenAccess` true) and put the language switches in the Tatakikun app, which the keyboard then reads. The app explains, in plain words and before iOS shows its "Allow Full Access" warning, what Full Access is used for (reading settings made in the app; copy and cut with Ctrl on iPad) and that typed text is not sent anywhere. Build this explanation once, shared with A04-cell054: whichever task gets there first builds it, the other reuses it. Without Full Access, the keyboard uses every installed language, and the app's switches say Full Access is needed (routine details: record them).
- macOS: still open for the person: should the settings also install and remove packs (download)? Not blocking: this task turns installed packs on and off (done, in the input menu); downloading would be a task of its own if the person wants it.
- Languages from the "five more languages" task should show up in this list too.

**Evidence.**
- Engine (merged into master): `Engine.turnedOff` holds the installed languages turned off; they give no candidates (whole words, completions, consonant abbreviations, slips, custom words), the letters as typed stay. `LanguagePackEngineTests.testTurnedOffLanguages`: with ja off, `watashi` gives no Japanese and `wts` no 私; with zh and en off, `ai` gives only Japanese (and the letters); turned on again, `watashi` → 私. `swift test`: 85 tests, 0 failures.
- Android (merged): the app's **Language packs** row opens **Input languages**, a switch for each pack; the row shows the languages that are on and how many. The keyboard applies the choice each time it comes up, so a change works at once. Checked on an emulator (Pixel 7, API 34): with 日本語 off, `watashi` showed only Chinese candidates; on again, 私 わたし came back; with English and 中文 off, 日本語 could not be turned off ("At least one language stays on"); the choice was kept after the app was stopped and started again.
- macOS (merged, built and unit-tested, not tried in the menu bar): the input menu (Tatakikun's menu in the menu bar) lists each installed language with a check mark; choosing one turns it on or off at once and is kept in the input method's defaults (`languagesOff`); the last one on is greyed out. Not reinstalled here: a reinstall leaves the person's Electron apps attached to the old process (project notes), so a person checks it.
- iOS: not done. The keyboard extension runs without Full Access (`RequestsOpenAccess` false), so it cannot read settings made in the Tatakikun app. Answered by the approver on 2026-10-25 (see Notes).
