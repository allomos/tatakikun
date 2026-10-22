# Allomos taskbag move (allomos/4 → allomos/5)

On 2026-10-22 the tasks in the taskbag written by the earlier Allomos (format allomos/4, set aside
as `.allomos/taskbag-allomos-4`) were moved into a new taskbag (`.allomos/taskbag`, allomos/5)
with `alm`. Every value was copied from the old files. The old taskbag, with its event history
(`events/`), is still in Git commit `0c234fb21e7835fca72d2150e0ea1debbc20f0c8`
(`git show 0c234fb:.allomos/taskbag/`).

## What moved

- Settings: the label ladder (implemented → locally verified → deployed and verified → human
  verified), the task language (`ui`) and the handoff rules (the defaults) are the same as the
  new taskbag's, so nothing was changed. The top label was already called "human verified".
- Areas A01–A04 and iterations I01–I05: same IDs, names and releases.
- 49 tasks: same IDs, areas, iterations, descriptions, states, labels, holders, handoff notes,
  what they wait on, check steps and reasons for finishing without the human check. 45 are done
  (13 of them still to check), 2 are waiting (A01-09, A01-12), 1 is ready (A02-easel451) and
  1 is dropped (A04-06).
- 9 English titles were translated into the task language (zh-CN): A02-09, A02-10, A02-11,
  A02-island506, A02-mantle732, A02-pit507, A04-10, A04-bean380, A04-garlic044.
- 7 handoffs, with their text unchanged and the same writer and tasks.
- `project-notes.md`: the same content, plus a line on where the old taskbag's history is.
- AGENTS.md: the Allomos section went from v23 to v24 (`alm brief`). CLAUDE.md already imports
  AGENTS.md.

## Card files

None. No task description had a `Card:` link, no old task folder had a `card.md`, and the
project has no files named after task IDs, no task board and no session register. So there is no
card file → task mapping, and there are no card files without a task.

## Values `alm` could not copy

- **Handoff dates:** each moved handoff's `written`/`updated` is now the date of the move.
  The originals were in the old handoff files' first lines (`handoffs/<file>.md`, lines 4–5):
  - claude-goal-1: written 2026-10-20T12:54Z, updated 2026-10-20T13:13Z
  - claude-punct: written and updated 2026-10-20T14:09Z
  - claude-abbrev: written and updated 2026-10-20T14:18Z
  - claude-packs: written 2026-10-20T14:46Z, updated 2026-10-20T15:10Z
  - claude-loop: written 2026-10-20T15:27Z, updated 2026-10-22T07:45Z
  - claude-release: written 2026-10-22T06:21Z, updated 2026-10-22T08:58Z
  - claude-unei: written and updated 2026-10-22T10:32Z
- **claude-release handoff:** it names no task (`2026-10-22-0621-claude-release.md`, line 3,
  `tasks:` is empty), so it was moved with no task, as it was. Its text also starts with a second,
  older header block (lines 8–13). That block was kept, because the text was not to be changed.
- **History and dates:** when each task was claimed, labelled or finished, and who made each
  change (`events/` in the old taskbag), is not copied. The new taskbag's history starts with the
  move, and the old events stay in commit 0c234fb. The old format kept no finish dates,
  priorities, dependencies or approvals apart from what the descriptions and handoff notes say.
- **Branches:** the old format recorded no base or working branch for a task. Every task now has
  `master` (the project's main branch) as its base. The finished tasks were claimed with
  `--branch master` to bring back their holders, so `master` as their working branch was added
  by the move and is not an old record.
- **Unknowns:** nothing unclear was filled in. The two waiting tasks with no holder (A01-09,
  A01-12) are still without one.

## Check

`alm list --json`: 49 tasks, `issues: []`. `alm cards`: no card files outside the taskbag.
