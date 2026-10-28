**Outcome.** On Android and iOS, holding a key brings up its symbol popup after 300 ms instead of 400 ms. A slider in each app's settings lets the person set the delay from 200 to 600 ms.

**Done means.**
- Android: `LONG_PRESS` in `android/app/src/main/java/com/tatakikun/android/KeyboardView.kt` no longer has a fixed 400 ms. It reads the setting, and the default is 300 ms.
- iOS: `longPress` in `iOS/Keyboard/KeyboardView.swift` no longer has a fixed 0.4 s. It reads the setting, and the default is 0.3 s. The keyboard extension reads the value the app saved (shared app group storage).
- Both settings screens have a "Long-press delay" slider, 200–600 ms, that shows the current value. A change takes effect the next time the keyboard opens, or sooner.
- Backspace's hold-to-repeat and every other long press follow the same delay.
- Checked by hand on a real Android phone and a real iPhone: 300 ms feels quicker, and 200 ms and 600 ms both work.

**Notes.**
- The approver chose this in conversation on 2026-10-28: default 300 ms on both platforms, plus a settings slider from 200 to 600 ms. The reason given: 400 ms felt long, and Gboard and SwiftKey default to about 300 ms.
- With TalkBack on, Android still uses the system's long-click (`setOnLongClickListener`). That path does not change.
- The step size, the label wording and where the slider sits in settings are routine choices: decide them and record them with `alm ai-decided`.

## Evidence

- 2026-10-28, claude-release: v0.6.16 released and installed on this Mac: approver typed 'alm guide github release install' in conversation, 2026-10-28. Release https://github.com/allomos/tatakikun/releases/tag/v0.6.16 (Mac pkg sha256 d561fb28…c47b, APK sha256 204abe8d…71be; 4 assets). Downloaded pkg checksum OK, installed 0.6.16, Tatakikun running (no workflow run; built locally).
