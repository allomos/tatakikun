**Outcome.** Turning a phone or tablet sideways no longer hides the app behind a full-screen edit box; the keyboard sits at the bottom with the app visible, and its keys are not stretched across the whole width.

**Done means.** On the emulator in landscape, a text field shows the app above the keyboard; the key area is capped in width and centred, rows are lower on short landscape screens; portrait is unchanged.

**Notes.** Asked by the person on 2026-10-23.

## Evidence

- 2026-10-23, claude-release: GitHub release v0.6.7 (2026-10-23, approved by the approver's `alm guide github release` in the conversation): tag v0.6.7 pushed; assets Tatakikun-0.6.7.pkg (22115312 bytes, +.sha256 142f021a…45aae6d) and Tatakikun-0.6.7-android.apk (89600411 bytes, versionCode 607, release cert 05d10759…bdb41, +.sha256 84c41f27…27f73f). Upgrade from the downloaded v0.6.6 APK (checksum OK) with adb install -r: Success; test-android.sh with the release APK 9/9 on Pixel_7_API_34; landscape screenshot: app field above the keyboard, keys centred, nihao → 你好. Mac .pkg downloaded, shasum OK, installed: 0.6.7. Release page 200.
