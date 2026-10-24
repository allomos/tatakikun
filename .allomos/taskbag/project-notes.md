# Project notes

What every session must know, whatever its task. Keep it short, and change lines in place.

## Running

- Android emulator Pixel_7_API_34, headless (started 2026-10-23 by claude-release; release-signed build of master after v0.6.9 (A04-elm284) installed 2026-10-24, versioned 0.6.9; learning persists between test runs on it): stop with `~/Library/Android/sdk/platform-tools/adb emu kill`.
- Android emulator Pixel_7_API_34_b, headless on port 5556 (started 2026-10-23 by claude-android-landscape; debug builds, long_press_timeout set to 1000): stop with `ANDROID_SERIAL=emulator-5556 ~/Library/Android/sdk/platform-tools/adb emu kill`.

## Pitfalls
- App icon (A01-plant167): edit `docs/icon/*.svg`, then `scripts/make-app-icons.sh` re-renders the checked-in icns, iOS AppIcon and Android foreground PNGs (needs rsvg-convert and ImageMagick); the Android background and monochrome vectors are kept by hand. The menu bar badge is separate (`scripts/make-icon.swift`).

- Dictionaries are generated, not committed: `scripts/build.sh` makes `build/dict` from this Mac's ICU data (~1 min), downloads the pinned open data into `build/sources` (~80 MB, `scripts/fetch-sources.sh`) and builds the language packs in `build/packs`. Tests skip without them.
- `build/dict` and `build/packs` are not rebuilt when the dictgen code changes: `scripts/build.sh` keeps existing files. After a change to how dictionaries or packs are made (costs, tables in `tatakikun-dictgen`), delete `build/dict` and run `scripts/build-packs.sh`, and do the same before a release; a stale `build/dict` fails `AbbreviationTests` (seen with nh → 你好, 2026-10-22). ../tatakikun-wt/cache may hold stale copies too.
- The app has no dictionaries of its own: it reads language packs from ~/Library/Application Support/Tatakikun/Packs/<zh|ja|en> (installed by `scripts/install.sh` or the .pkg from `scripts/make-installer.sh`). For development set TATAKIKUN_PACKS=build/packs (or TATAKIKUN_DICT=build/dict for the base dictionaries).
- Pack licenses: only permissive data (MIT, IPAdic, SCOWL, Unicode; jieba word frequencies, MIT, since A02-09) — the person asked to avoid GPL data (2026-10-20).
- A new input method shows up in System Settings only after it is in ~/Library/Input Methods, sometimes only after logging out and in. After reinstalling, `scripts/install.sh` kills the running Tatakikun so the new one loads. Changes to Info.plist input-source keys (such as `TISIntendedLanguage`) are cached by the system: call `TISRegisterInputSource` on ~/Library/Input Methods/Tatakikun.app (or log out and in) before checking them.
- Task worktrees live in ../tatakikun-wt/<task>; copy build/dict, build/sources and build/packs into a new worktree rather than regenerating (../tatakikun-wt/cache has copies).
- Every reinstall (`scripts/install.sh` kills the running Tatakikun) leaves Electron apps (VS Code, Slack) attached to the dead process: the menu bar shows Tatakikun but keys do nothing there, while native apps (TextEdit) reconnect on their own. Quit those apps with ⌘Q and reopen them (confirmed 2026-10-22). Never start `.build/release/Tatakikun` without `--demo`: it ignores other arguments such as `--help` and runs as a second input method server.
- Tatakikun gone from the input menu after an install (v0.6.9, 2026-10-24): it was not running and was dropped from the enabled input sources. Start it with `launchctl kickstart -k gui/$(id -u)/com.tatakikun.inputmethod.Tatakikun`. If the menu still leaves it out while System Settings > Keyboard > Input Sources lists it (re-enabling with TIS, `defaults write`, restarting TextInputMenuAgent or cfprefsd, cleaning LaunchServices did not help), remove it there with − and add it back with + > 簡体中国語 > Tatakikun: that brought it back at once, no logout.
- After many reinstalls in one session, the ⌘Space / Ctrl+Space input source list can stop appearing altogether (the source still switches), even with Tatakikun removed; logging out does not fix it, restarting the Mac does.
- Keep `TISIntendedLanguage` = `zh-Hans`: with `en` (A04-06), macOS leaves Tatakikun out of the ⌘Space / Ctrl+Space list (reverted in A04-08, v0.5.1). `ja` does not make the かな key reach Tatakikun either (it only goes to Apple's Japanese input method).
- macOS does not start Tatakikun after login (typing did nothing until a window change); input modes (`ComponentInputModeDict`), `LSUIElement` and `lsregister` did not help, and modes stop it starting even mid-session. install.sh and the installer add a login item (~/Library/LaunchAgents/com.tatakikun.inputmethod.Tatakikun.plist) instead (A04-09, v0.5.2).
- Tests use the system spell checker for English (`SystemEnglish`); inside `xctest` its completions can come back empty (seen 2026-10-21), failing `testExpandedRowsIncludePartialMatches` while the app, which uses the en pack, is fine. Check with `tatakikun-cli --packs build/packs compu` before suspecting the code.
- iOS (A01-11): `scripts/build-ios.sh [test]` builds `iOS/` for the simulator (and runs the UI tests); edit `iOS/project.yml` and regenerate with XcodeGen (`brew install xcodegen`), the generated project is committed. A simulator without a window never shows a third-party keyboard in other apps: the UI tests use the app's demo screen; the extension itself needs a person (or the Simulator app with its hardware keyboard off).
- `tatakikun-cli` ignores TATAKIKUN_PACKS: without `--packs build/packs` it uses the base dictionaries (build/dict) and the Mac spell checker, which is not what the app uses. `ExpandTests.testExpandedRowsIncludePartialMatches` depends on that spell checker (compu → computer) and failed once on master (2026-10-21), then passed.
- Android (A02-island506): `scripts/build-android.sh` builds the engine as libTatakikunEngine.so with the open-source Swift 6.3.3 toolchain (~/Library/Developer/Toolchains, per user) and the Swift SDK for Android 6.3.3 (`swift sdk list`), NDK 28.2 in ~/Library/Android/sdk. The SDK must match the toolchain exactly: Xcode's Swift 6.4 has no Android SDK.
- The engine and tatakikun-cli import FoundationEssentials where it exists (A02-mantle732): no NSData, NSString, memcmp or other APIs that only full Foundation brings; macOS/iOS still compile against Foundation, so only the Android build (or Windows CI) catches a slip.
- Windows: GitHub Actions `.github/workflows/windows.yml` builds tatakikun-cli and runs the engine tests on every push to master; the program is the run's artifact `tatakikun-cli-windows-x64`. No Windows machine here: the person tests on their PC.
- Android app (A01-10): `scripts/build-android-app.sh [install]` builds the engine and `android/` (Gradle 8.14.4 wrapper, AGP 8.13, Android Studio's Java via JAVA_HOME, SDK in ~/Library/Android/sdk); `scripts/test-android.sh` types on a running emulator (AVD Pixel_7_API_34, arm64: `~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34 -no-window &`). Force-stopping the app also stops the keyboard and Android falls back to Gboard (select it again); leave the app for ~2 s before coming back or the input does not end (momentum stays).
- Android emulators for parallel sessions: one AVD runs only once; Pixel_7_API_34_c (created 2026-10-24 by claude-loop2) is a third one (`-port 5558`); Pixel_3a_API_33 has no system image. On a fresh AVD the keyboard stays hidden until `adb shell settings put secure show_ime_with_hard_keyboard 1`. `adb shell input tap` takes 0.1–0.8 s per tap, too slow for a double tap; with three emulators and the iOS simulator running, the Mac's load went to 35–50 and the emulator stalled ("System UI isn't responding").
- Two sessions on one emulator clash: installing an APK replaces the other session's build mid-test (seen 2026-10-23). Pixel_7_API_34 was not started with `-read-only`, so a second copy of it cannot run; a second AVD, Pixel_7_API_34_b (same image), runs beside it: `~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34_b -no-window -port 5556 &`, then `ANDROID_SERIAL=emulator-5556` for adb and `scripts/test-android.sh` (with two emulators up, plain `adb` refuses to pick one).
- History: the taskbag written by the earlier Allomos (format allomos/4), with its event history (`events/`) and its original handoffs, is in Git commit `0c234fb21e7835fca72d2150e0ea1debbc20f0c8` (`git show 0c234fb:.allomos/taskbag/`); it was moved into this taskbag on 2026-10-22 (docs/allomos-conversion.md).

## Repositories

Where the code and this taskbag are kept online, one list item each, so an agent working from a
copy elsewhere (in the cloud, say) can find both: `- Code: https://github.com/<owner>/<repo>`.
The address only: never a token or a personal detail.
- Code and taskbag: https://github.com/allomos/tatakikun (public, MIT)

## Releases

Facts for `alm guide github-release` (derived from the repository 2026-10-22, before v0.6.1).

| Key | Value |
|---|---|
| `REMOTE` | https://github.com/allomos/tatakikun |
| `BASE_BRANCH` | `master` |
| `VERSION_FILES` | `App/Info.plist` `CFBundleShortVersionString` (`0.6.1`, no `v`); `CFBundleVersion` stays `1`. The installer's version comes from it. The iOS app's own version (`iOS/project.yml` `MARKETING_VERSION`) is not released and not bumped. |
| `TAG_FORMAT` | `vX.Y.Z`, annotated, message `Tatakikun vX.Y.Z` |
| `BUMP` | patch, unless the approver says `minor` or `major` |
| `RELEASE_WORKFLOW` | None for the Mac release: built on this Mac with `scripts/make-installer.sh` (~2 min, needs build/dict and build/packs) and published with `gh release create`. `.github/workflows/windows.yml` runs on every push to master (CI only, ~10–35 min); it publishes nothing. |
| `NOTES_DIR` | None: the notes are the GitHub release's own body, in the shape of the last release (intro paragraph, Chinese one-liner, `## New/Fixed in vX.Y.Z`, `## Install` with the SHA-256, license line). |
| `NOTES_LANGUAGES` | English body, with the one-line Chinese description kept from the last release. |
| `NOTES_INDEX` | None. |
| `NOTES_URL` | https://github.com/allomos/tatakikun/releases/tag/vX.Y.Z |
| `NOTES_PUBLISH` | Published with the release by `gh release create --notes-file`. |
| `GH_NOTES` | The agent writes them; they link to the previous release for everything unchanged. |
| `ANDROID_ASSET` | From v0.6.3: `Tatakikun-X.Y.Z-android.apk` (arm64, Android 9+) and its `.sha256`, built by `scripts/build-android-app.sh release` into `build/` (version from `App/Info.plist`, versionCode X*10000+Y*100+Z, signed with the key under Where credentials live) and uploaded to the same release; the notes' Install section has an Android line. Check it first: `APK=build/Tatakikun-X.Y.Z-android.apk scripts/test-android.sh` (uninstall a debug build first: other signature). Not installed on this computer. |
| `INSTALL_ASSET` | `Tatakikun-X.Y.Z.pkg` (Apple silicon and Intel), with `Tatakikun-X.Y.Z.pkg.sha256` (from v0.6.1; earlier releases give the SHA-256 in the notes only). `scripts/make-installer.sh` does not write the `.sha256`: `(cd build && shasum -a 256 Tatakikun-X.Y.Z.pkg > Tatakikun-X.Y.Z.pkg.sha256)`. |
| `INSTALL_COMMAND` | `installer -pkg Tatakikun-X.Y.Z.pkg -target CurrentUserHomeDirectory`: installs into the user's Library, no password; all three packs by default. Then `launchctl kickstart -k gui/$(id -u)/com.tatakikun.inputmethod.Tatakikun` so the new build loads and keeps running (a plain `pkill` left it stopped and dropped from the enabled input sources, 2026-10-24). |
| `VERIFY_INSTALLED` | `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" ~/Library/Input\ Methods/Tatakikun.app/Contents/Info.plist`, and `pgrep -x Tatakikun` after typing in any app. |
| `APPROVAL_RECORD` | `alm handoff <task> --as <session> --evidence "…"` on the task the release ships (from v0.6.4, alm v25 writes handoffs per task): the approver's command line, when, and the evidence. Earlier releases' records are in Git history (handoffs/2026-10-22-1337-claude-release.md). |

## Where credentials live

Never their values, and no personal details (email addresses, account names): write a
placeholder such as `<ACCOUNT_EMAIL>` and how to look it up.

- Android release signing key (A01-mitten679): `~/.config/tatakikun/android-release.jks` and its passwords in `~/.config/tatakikun/android-signing.properties` (mode 600), on the Mac that released v0.6.3 only; certificate SHA-256 05d10759…bdb41. Every later APK must be signed with it or phones cannot update in place: keep a backup outside this Mac.

## Agents set up

AI agents whose rule files follow AGENTS.md (`alm guide agent-files`): agent, its file, date.
- Claude Code: CLAUDE.md (imports AGENTS.md), 2026-10-20
