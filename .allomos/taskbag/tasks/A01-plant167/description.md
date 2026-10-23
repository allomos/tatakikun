**Outcome.** The macOS app, the iOS app and the Android launcher show the new Tatakikun icon (teal background, white key with た, gold Allomos star).

**Done means.**
- macOS: Tatakikun.app built by scripts/build.sh shows the icon in Finder.
- iOS: the app built from iOS/ shows the icon on the simulator home screen.
- Android: the APK shows the icon in the launcher (adaptive icon, also on round masks).

**Notes.** Design approved by the person in conversation on 2026-10-23 ("Wire the new icon into the macOS app, iOS app and Android launcher builds"). Sources: docs/icon/tatakikun-icon.svg (macOS, with padding) and docs/icon/tatakikun-icon-fullbleed.svg (iOS/Android). The menu bar input-source icon (scripts/make-icon.swift) stays as it is.
