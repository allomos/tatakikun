**Outcome.** Opening Tatakikun from the launcher (or the keyboard's ⚙ key) shows a designed settings screen instead of the plain stacked buttons: a header, the two setup steps with whether each is done, a field to try the keyboard, and the installed language packs / version.

**Done means.**
- The screen follows the design sample the person picks; light and dark mode both look right.
- Step 1 (enable in system settings) and step 2 (choose as current keyboard) show done/not-done and update when you come back to the app.
- The try-it field still works; the keyboard's settings key still opens this screen.
- Screenshots on an Android device/emulator in light and dark mode under **Evidence**.

**Notes.**
- Design: sample B (hero and checklist), chosen by the person on 2026-10-23 in the session that added this task.
- Code: android/app/src/main/java/com/tatakikun/android/MainActivity.kt (views built in code, no XML layouts, no AndroidX), themes in res/values{,-night}/themes.xml.

**Evidence** (2026-10-23, branch feat/android-settings-b, commit fe90f6d; emulator Pixel_7_API_34_b, Android 14, own AVD so the shared emulator-5554 was left alone)
- Debug build installed; screenshots taken in light and dark mode for: keyboard off (both steps ○, "After you turn it on"), enabled only (step 1 ✓ Done, step 2 "Switch to Tatakikun"), enabled and chosen (both ✓ Done). The state follows `ime enable/set/disable` each time the screen comes back.
- No system title bar; the header sits below the status bar and scrolled content does not show through it.
- Tapping Try it brings up Tatakikun, the field scrolls above the keyboard, `woaini` shows 我爱你 first.
- `ANDROID_SERIAL=emulator-5556 scripts/test-android.sh`: all 9 checks passed (woaini → 我爱你, nihao → 你好, watashi → 私, hello, sute-tasu → ステータス, niyongguolema → 你用过了吗, 你好，, woaini ENTER, 愛愛).
- Not checked: Android 15+ device (the emulator is Android 14), tapping About (opens the browser) and the system keyboard picker by hand.

## Evidence

- 2026-10-23, claude-android-settings: Release v0.6.5, approved by the approver's line "when finished, call alm guide github release" in the session claude-android-settings on 2026-10-23 (patch bump, install here). Version commit 'Tatakikun 0.6.5' (App/Info.plist), annotated tag v0.6.5 pushed; built locally (scripts/make-installer.sh, scripts/build-android-app.sh release, signer SHA-256 05d10759…bdb41); release APK passed scripts/test-android.sh 9/9 on an Android 14 emulator before tagging. gh release create v0.6.5 with 4 assets: Tatakikun-0.6.5.pkg (21937919 B, SHA-256 a8649aa4…3a1d), .pkg.sha256, Tatakikun-0.6.5-android.apk (89559163 B, SHA-256 0279d3aa…32ce), .apk.sha256; marked Latest; https://github.com/allomos/tatakikun/releases/tag/v0.6.5 answers 200. Downloaded into a new folder, checksum OK, installed with installer -target CurrentUserHomeDirectory, pkill Tatakikun; installed version 0.6.5. Notes: New (2: Android settings screen, key popups), Fixed (1: bottom row clear of the navigation bar's buttons on Android 15+).
