**Outcome.** The Swift engine builds and passes its tests on Windows, and the person can try a Windows build of `tatakikun-cli` from a GitHub release on their own Windows PC.

**Done means.**
- A GitHub Actions workflow builds TatakikunCore and tatakikun-cli on a Windows runner and runs the engine tests there.
- A `tatakikun-cli` Windows build (with the dictionaries it needs) is attached to a GitHub release (pre-release), after the person approves publishing it.
- The person runs it on their Windows PC and sees the same candidates as on macOS.

**Notes.**
- No Windows VM here (person, 2026-10-22): CI builds it, the person tests the release on their PC.
- Publishing the release is an outside effect: ask the person first.

**Evidence.**
- `.github/workflows/windows.yml` (every push to master): a macOS job builds build/dict and the language packs; the Windows job (windows-latest, Swift 6.3.3) builds tatakikun-cli, runs all 72 engine tests against those dictionaries (0 skipped, 0 failures), runs the CLI, and keeps the program + Swift runtime DLLs + packs as the artifact tatakikun-cli-windows-x64 (~51 MB zipped). First green run: 39633109455; with reproducible packs: 39635979463.
- Windows output equals macOS for `woaini watashi hello chongqizhiqian zhogn` (diffed).
- Fixes it needed: CLI `trimmingCharacters` (not in FoundationEssentials); Package.swift declares the macOS app and dictgen only on macOS; tests no longer call `XCTestCase()`; English from the pack where there is no system spell checker; packs sorted by word bytes for equal costs (builds were not reproducible: 仲/忠 swapped).
- Not done yet: the pre-release (needs the person's OK) and the person's try on their PC.
