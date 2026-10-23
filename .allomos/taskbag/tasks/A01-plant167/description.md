**Outcome.** The macOS app, the iOS app and the Android launcher show the new Tatakikun icon (teal background, white key with た, gold Allomos star).

**Done means.**
- macOS: Tatakikun.app built by scripts/build.sh shows the icon in Finder.
- iOS: the app built from iOS/ shows the icon on the simulator home screen.
- Android: the APK shows the icon in the launcher (adaptive icon, also on round masks).

**Notes.** Design approved by the person in conversation on 2026-10-23 ("Wire the new icon into the macOS app, iOS app and Android launcher builds"). Sources: docs/icon/tatakikun-icon.svg (macOS, with padding), docs/icon/tatakikun-icon-fullbleed.svg (iOS), docs/icon/tatakikun-icon-android-foreground.svg (Android); `scripts/make-app-icons.sh` renders the checked-in platform files. The menu bar input-source icon (scripts/make-icon.swift) stays as it is.

## Evidence

- Merged to master in b0b1ad2 (branch feat/app-icon).
- macOS: `scripts/build.sh` passed; build/Tatakikun.app has Contents/Resources/AppIcon.icns (1024 px largest) and CFBundleIconFile = AppIcon; NSWorkspace returns the new icon for the bundle after `lsregister -f`.
- iOS: `scripts/build-ios.sh` passed (XcodeGen regenerated the project); the bundle has Assets.car and AppIcon60x60@2x.png; on the iPhone 16 Pro simulator the home screen shows Tatakikun with the new icon.
- Android: `scripts/build-android-app.sh` passed; aapt2 badging shows icon res/mipmap-anydpi-v26/ic_launcher.xml at every density; on emulator Pixel_7_API_34 the app drawer shows the new icon in the circle mask.
