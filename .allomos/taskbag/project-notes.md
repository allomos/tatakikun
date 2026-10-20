# Project notes

What every session must know, whatever its task. Keep it short, and change lines in place.

## Running

Nothing.

## Pitfalls

- Dictionaries are generated, not committed: `scripts/build.sh` makes `build/dict` from this Mac's ICU data (~1 min). Tests skip without it.
- A new input method shows up in System Settings only after it is in ~/Library/Input Methods, sometimes only after logging out and in. After reinstalling, `scripts/install.sh` kills the running Tatakikun so the new one loads.
- Task worktrees live in ../tatakikun-wt/<task>; copy build/dict into a new worktree rather than regenerating.

## Repositories

Where the code and this taskbag are kept online, one list item each, so an agent working from a
copy elsewhere (in the cloud, say) can find both: `- Code: https://github.com/<owner>/<repo>`.
The address only: never a token or a personal detail. None yet.

## Where credentials live

Never their values, and no personal details (email addresses, account names): write a
placeholder such as `<ACCOUNT_EMAIL>` and how to look it up. None yet.

## Agents set up

AI agents whose rule files follow AGENTS.md (`alm guide agent-files`): agent, its file, date.
- Claude Code: CLAUDE.md (imports AGENTS.md), 2026-10-20
