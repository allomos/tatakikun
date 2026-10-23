**Outcome.** On the Android keyboard, every character key (letters, digits, symbols, ， and 。) shows a small popup above the finger with the character it types, so the person can see what they pressed even though the finger covers the key. A long press turns the popup into the long-press symbol (for example g → &, ， → 、), and that is what gets typed.

**Done means.**
- Tap a letter, digit or symbol: a popup with that character appears above the key while the finger is down and disappears on release; shift shows the capital.
- Long press a key with a corner symbol: the popup switches to the symbol; releasing types it.
- Keys at the edges (q, p, 1, 0) keep the popup fully on screen; the number row's popup is not cut off at the top.
- No popup on space, shift, delete, return and ?123 (as on Gboard and iOS).
- Light and dark mode readable; fast typing does not leave stale popups; test-android.sh passes.

**Notes.**
- Design samples (three ways, plus today's keyboard): https://claude.ai/artifact/BagrRgRszrB2vKng3kVDiM
- How other keyboards do it: Gboard shows a separate balloon above the key ("Pop-up on keypress", on by default); long press opens a row of alternatives you slide across, released on the highlighted one. iOS grows the key upward into a connected callout (tulip shape); long press opens an accent row. SwiftKey and Samsung Keyboard use a Gboard-like balloon. Chinese IMEs (Sogou, Baidu) use a balloon and show the long-press symbol in it.
- Decided by the approver in the conversation, 2026-10-23: design B (Tatakikun balloon: the corner symbol small inside, flips to the symbol on the function-key blue on long press); a long press types on release (sliding off the key cancels); no on/off switch for now.
