**Outcome.** Opening Tatakikun from the launcher (or the keyboard's ⚙ key) shows a designed settings screen instead of the plain stacked buttons: a header, the two setup steps with whether each is done, a field to try the keyboard, and the installed language packs / version.

**Done means.**
- The screen follows the design sample the person picks; light and dark mode both look right.
- Step 1 (enable in system settings) and step 2 (choose as current keyboard) show done/not-done and update when you come back to the app.
- The try-it field still works; the keyboard's settings key still opens this screen.
- Screenshots on an Android 15 device/emulator in light and dark mode under **Evidence**.

**Notes.**
- Open for the person: which design sample to build (samples shown in the session that added this task). What users see is theirs to decide.
- Current code: android/app/src/main/java/com/tatakikun/android/MainActivity.kt (views built in code, no XML layouts, no AndroidX).
