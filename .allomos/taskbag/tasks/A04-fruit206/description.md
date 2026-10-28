**Outcome.** A quick tap on a letter key shows its popup long enough to read; until now it went 50 ms after the finger lifted (about 100 ms in all).

**Done means.** The popup stays at least 200 ms from when it appeared (a press held longer hides 50 ms after lifting, as before); pressing the next key still takes the popup over at once; sliding off or a cancelled touch still hide it at once. Android build and unit tests pass.

**Notes.** Asked by the approver in chat (option 2: a minimum time on screen, 200 ms).
