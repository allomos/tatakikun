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
