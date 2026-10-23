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
