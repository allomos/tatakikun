**Outcome.** The Swift engine builds and passes its tests on Windows, and the person can try a Windows build of `tatakikun-cli` from a GitHub release on their own Windows PC.

**Done means.**
- A GitHub Actions workflow builds TatakikunCore and tatakikun-cli on a Windows runner and runs the engine tests there.
- A `tatakikun-cli` Windows build (with the dictionaries it needs) is attached to a GitHub release (pre-release), after the person approves publishing it.
- The person runs it on their Windows PC and sees the same candidates as on macOS.

**Notes.**
- No Windows VM here (person, 2026-10-22): CI builds it, the person tests the release on their PC.
- Publishing the release is an outside effect: ask the person first.
