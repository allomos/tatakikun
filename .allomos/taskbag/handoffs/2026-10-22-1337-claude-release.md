---
writer: claude-release
tasks: 
written: 2026-10-22T13:37Z
updated: 2026-10-22T13:37Z
---

---
writer: claude-release
tasks: 
written: 2026-10-22T06:21Z
updated: 2026-10-22T06:21Z
---

# Handoff: claude-release, GitHub release v0.6.1

## Approval
- The approver wrote `alm guide github release` in the conversation on 2026-10-22, then repeated it after seeing the derived release facts and notes (no `minor`/`major`, so patch).

## What was done
- Wrote `## Releases` in project-notes.md (first time; derived from the repository).
- Version 0.6.1 in App/Info.plist; commit 66b6f3a on master, annotated tag v0.6.1, both pushed.
- Release https://github.com/allomos/tatakikun/releases/tag/v0.6.1 (Latest): New 3, Fixed 2, Also 2.
- Installed on this Mac from the downloaded asset with `installer -pkg … -target CurrentUserHomeDirectory`.

## Evidence
- `swift test`: 72 tests, 0 failures. Installer universal (arm64, x86_64), 22220077 bytes.
- Assets: Tatakikun-0.6.1.pkg, Tatakikun-0.6.1.pkg.sha256 (first release with a checksum file).
- SHA-256 124c2932d5b4623529179b5e193139901d4a8276f28cea9e6a8df55aadd61229, `shasum -c` OK on the download.
- Release page answers 200, title "Release Tatakikun v0.6.1".
- Installed version: 0.6.1; packs en, ja, zh.
- No release workflow (built locally); Windows CI is test-only and was not involved.

## Not done / not checked
- Typing in a real app after the install is the person's check.
- Left out of the notes: AGENTS.md update, Allomos app changes, handoffs and taskbag commits.
- A02-pit507's Windows pre-release (proposed tag v0.6.1-windows-preview.1) still waits for the person's OK; untouched.

# GitHub release v0.6.2

## Approval
- The approver wrote `alm guide github release` in the conversation on 2026-10-22 (no `minor`/`major`, so patch).

## What was done
- Version 0.6.2 in App/Info.plist; commit 71f5908 on master, annotated tag v0.6.2, both pushed.
- Release https://github.com/allomos/tatakikun/releases/tag/v0.6.2 (Latest): New 2, Fixed 3, Also 2.
- Installed on this Mac from the downloaded asset (`installer -pkg … -target CurrentUserHomeDirectory`).

## Evidence
- `swift test`: 79 tests, 0 failures. tatakikun-cli: niyongguolema → 你用过了吗, guole → 过了, sute-tasu → ステータス.
- Assets: Tatakikun-0.6.2.pkg (21932740 bytes, arm64 + x86_64), Tatakikun-0.6.2.pkg.sha256.
- SHA-256 594439643dfc3741ba7cbd08421a77ee97b7b41735b45c03dc5eddde0e52e8d3, `shasum -c` OK on the download.
- Release page answers 200. Installed version 0.6.2; packs en, ja, zh.

## Not done / not checked
- Typing in a real app after the install is the person's check (Tatakikun starts when a text field asks for it).
- Left out of the notes: Windows CI path filter, project-notes and handoff commits.
- The Android app is not built or attached; the notes say how to build it.
