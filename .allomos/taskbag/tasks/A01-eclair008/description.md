**Outcome.** On the Android and iOS keyboards, Tatakikun keeps a history of recently copied text. The person opens it from the keyboard, sees the recent items, and taps one to paste it into the current text field; the latest copy can be pasted in one tap.

**Design (approved by the person, 2026-10-26: A + B + C).**
- **A, the list.** A clipboard button in the bar above the keys. Tapping it replaces the keys with the list of copies, newest first, each a one- or two-line preview with × to delete it; a back arrow returns to the keys and a trash icon clears the history. Tapping an item pastes its full text at the cursor and the keys come back.
- **B, the one-tap chip.** After a new copy, the latest copied text shows as a chip next to the clipboard button. Tapping it pastes that text; the chip then goes away (the text stays in the list from A).
- **C, iOS without Full Access.** On iOS, if "Allow Full Access" is off, tapping the clipboard button shows a short explanation (the history needs Full Access and stays on this iPhone) and an Open Settings button instead of an empty list. Once it is on, A and B work.

**Done means.**
- A: copy a few pieces of text in other apps, open the list from the keyboard: the items are newest first; tapping one inserts it at the cursor and the keys return; × deletes one item, the trash icon clears all.
- B: copy text, switch to another app's text field: the chip shows the copy; tapping it pastes it and the chip goes away.
- C: on iOS with Full Access off, the explanation and Open Settings show instead of the list.
- Copying the same text again moves it to the top instead of adding a duplicate; the list keeps a bounded number of recent items (the oldest drop off); the history survives closing the keyboard.
- Light and dark mode readable; Android and iOS unit tests pass; A, B and C work in the emulator / simulator (screenshots).

**Notes.**
- Requested by the person (2026-10-26); kept in backlog at their request.
- Android: as the active input method, the keyboard can read the clipboard (Android 10+ allows the focused IME); listen with ClipboardManager while the keyboard runs.
- iOS: a keyboard extension cannot observe the clipboard in the background, so it can only record what is on the pasteboard when the keyboard appears (needs Full Access; `RequestsOpenAccess` is already on). Say so in the human-check steps.
- Privacy: the history is stored only on the device, never sent anywhere; text from password fields is not recorded where the platform marks it (Android `ClipDescription` sensitive flag, secure text fields).
- Routine choices (icons, how many items, how long the chip stays, the preview length, storage) are for whoever works the task: record them with `alm ai-decided`.

## Evidence

- 2026-10-26, claude-release: Released v0.6.13 (also ships A04-tassel550, A02-town861, A04-aster924, A01-ginger506), approved by the person's line 'alm guide github release' on 2026-10-26: commit bfc6c45 (Tatakikun 0.6.13), annotated tag v0.6.13 pushed, release https://github.com/allomos/tatakikun/releases/tag/v0.6.13 (Latest) with Tatakikun-0.6.13.pkg (29550103 B, SHA-256 5ed0af39…11cc4), its .sha256, Tatakikun-0.6.13-android.apk (116286621 B, versionCode 613, signed with the release key 05d10759…bdb41, SHA-256 a5bae6e4…2e92) and its .sha256. build/dict rebuilt and packs rebuilt first; swift test 123 tests, 0 failures. Downloaded pkg checksum OK, installed on this Mac (installer -target CurrentUserHomeDirectory, launchctl kickstart): installed version 0.6.13, Tatakikun running. Not done: APK not run on an emulator (no mobile testing unless asked).
