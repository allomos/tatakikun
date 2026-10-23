**Outcome.** On Android 15 and later the keyboard ends above the navigation bar, so ⌄ (hide keyboard) and the keyboard-switch globe do not overlap the bottom row (?123, comma, space, 。, return).

**Done means.**
- On an Android 15+ phone with gesture navigation, ⌄ and the globe sit below the bottom row, on the keyboard's background.
- Android 14 and earlier look the same as before (no extra gap).
- test-android.sh passes.

**Notes.**
- Reported by the approver with a screenshot from their phone (2026-10-23).
- Cause: when the IME draws its own navigation bar, Android reports it to the IME as a caption-bar inset, not a navigation-bar inset (AOSP NavigationBarController sizes its frame from systemBars()). KeyboardView read navigationBars() only, which is 0 there.
