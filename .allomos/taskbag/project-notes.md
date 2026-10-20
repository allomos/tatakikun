# Project notes

What every session must know, whatever its task. Keep it short, and change lines in place.

## Running

Nothing.

## Pitfalls

- Dictionaries are generated, not committed: `scripts/build.sh` makes `build/dict` from this Mac's ICU data (~1 min), downloads the pinned open data into `build/sources` (~80 MB, `scripts/fetch-sources.sh`) and builds the language packs in `build/packs`. Tests skip without them.
- The app has no dictionaries of its own: it reads language packs from ~/Library/Application Support/Tatakikun/Packs/<zh|ja|en> (installed by `scripts/install.sh` or the .pkg from `scripts/make-installer.sh`). For development set TATAKIKUN_PACKS=build/packs (or TATAKIKUN_DICT=build/dict for the base dictionaries).
- Pack licenses: only permissive data (MIT, IPAdic, SCOWL, Unicode) — the person asked to avoid GPL data (2026-10-20).
- A new input method shows up in System Settings only after it is in ~/Library/Input Methods, sometimes only after logging out and in. After reinstalling, `scripts/install.sh` kills the running Tatakikun so the new one loads. Changes to Info.plist input-source keys (such as `TISIntendedLanguage`) are cached by the system: call `TISRegisterInputSource` on ~/Library/Input Methods/Tatakikun.app (or log out and in) before checking them.
- Task worktrees live in ../tatakikun-wt/<task>; copy build/dict, build/sources and build/packs into a new worktree rather than regenerating (../tatakikun-wt/cache has copies).
- After many reinstalls in one session, the ⌘Space / Ctrl+Space input source list can stop appearing altogether (the source still switches), even with Tatakikun removed; logging out does not fix it, restarting the Mac does.
- Keep `TISIntendedLanguage` = `zh-Hans`: with `en` (A04-06), macOS leaves Tatakikun out of the ⌘Space / Ctrl+Space list (reverted in A04-08, v0.5.1). `ja` does not make the かな key reach Tatakikun either (it only goes to Apple's Japanese input method).
- macOS does not start Tatakikun after login (typing did nothing until a window change); input modes (`ComponentInputModeDict`), `LSUIElement` and `lsregister` did not help, and modes stop it starting even mid-session. install.sh and the installer add a login item (~/Library/LaunchAgents/com.tatakikun.inputmethod.Tatakikun.plist) instead (A04-09, v0.5.2).
- Tests use the system spell checker for English (`SystemEnglish`); inside `xctest` its completions can come back empty (seen 2026-10-21), failing `testExpandedRowsIncludePartialMatches` while the app, which uses the en pack, is fine. Check with `tatakikun-cli --packs build/packs compu` before suspecting the code.
- iOS (A01-11): `scripts/build-ios.sh [test]` builds `iOS/` for the simulator (and runs the UI tests); edit `iOS/project.yml` and regenerate with XcodeGen (`brew install xcodegen`), the generated project is committed. A simulator without a window never shows a third-party keyboard in other apps: the UI tests use the app's demo screen; the extension itself needs a person (or the Simulator app with its hardware keyboard off).
- `ExpandTests.testExpandedRowsIncludePartialMatches` fails on master (seen 2026-10-21): with the base dictionaries, `compu` → computer comes from the Mac's spell checker, which no longer returns it. Not caused by A01-11.

## Repositories

Where the code and this taskbag are kept online, one list item each, so an agent working from a
copy elsewhere (in the cloud, say) can find both: `- Code: https://github.com/<owner>/<repo>`.
The address only: never a token or a personal detail.
- Code and taskbag: https://github.com/allomos/tatakikun (public, MIT)

## Where credentials live

Never their values, and no personal details (email addresses, account names): write a
placeholder such as `<ACCOUNT_EMAIL>` and how to look it up. None yet.

## Agents set up

AI agents whose rule files follow AGENTS.md (`alm guide agent-files`): agent, its file, date.
- Claude Code: CLAUDE.md (imports AGENTS.md), 2026-10-20
