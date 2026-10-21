**Outcome.** When the current (highlighted) candidate is an English word and the user presses Space, Tatakikun commits that word followed by one half-width space, so English words can be typed one after another without an extra keystroke.

**Done means.**
- Typing `hello`, Space, `world`, Space in any app gives `hello world `.
- When the current candidate is Chinese or Japanese, Space commits it as before, with no space added.
- Works in the macOS input method and the iOS keyboard (A01-11), if both share the commit logic.
- Unit tests cover English and non-English candidates committed with Space.

**Notes.**
- Related: A04-03 (punctuation and spaces follow the preceding text: half-width after English).
- Routine choices for whoever works it (record with `alm ai-decided`): whether Enter and number-key selection also add the space (default: only Space adds it), and how the raw letter string candidate is treated (default: counts as English).
