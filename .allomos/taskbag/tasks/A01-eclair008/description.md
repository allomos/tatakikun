**Outcome.** On the Android and iOS keyboards, Tatakikun keeps a history of recently copied text. The person opens it from the keyboard, sees the recent items, and taps one to paste it into the current text field.

**Done means.**
- Copy a few pieces of text in other apps, then open the clipboard history from the Tatakikun keyboard: the items are listed newest first, each shown as a one- or two-line preview.
- Tapping an item inserts its full text at the cursor; the keyboard returns to typing.
- Copying the same text again moves it to the top instead of adding a duplicate; the list keeps a bounded number of recent items (the oldest drop off).
- The person can delete a single item and clear the whole history; the history survives closing the keyboard.
- iOS: without "Allow Full Access" the history explains how to turn it on instead of showing an empty or broken list.
- Light and dark mode readable; Android and iOS unit tests pass; the history works in the emulator / simulator (screenshots).

**Notes.**
- Requested by the person (2026-10-26); kept in backlog at their request.
- Android: as the active input method, the keyboard can read the clipboard (Android 10+ allows the focused IME); listen with ClipboardManager while the keyboard runs.
- iOS: a keyboard extension cannot observe the clipboard in the background, so it can only record what is on the pasteboard when the keyboard appears (needs Full Access; `RequestsOpenAccess` is already on). Say so in the human-check steps.
- Privacy: the history is stored only on the device, never sent anywhere; text from password fields is not recorded where the platform marks it (Android `ClipDescription` sensitive flag, secure text fields).
- Routine choices (where the button sits, how many items, the item preview, storage) are for whoever works the task: record them with `alm ai-decided`.
