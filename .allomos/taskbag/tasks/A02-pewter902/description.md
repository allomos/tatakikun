**Outcome.** The Windows CI run on master (.github/workflows/windows.yml) passes again. It had failed on every push since the Spanish pack: the five language test files (Spanish, French, Hindi, Bengali, Arabic) called `LanguagePackEngineTests()`, and XCTest on Windows and Linux has no plain `init()` for a test case.

**Done means.**
- The Windows run on master passes.
- `swift test` on the Mac passes for the language pack tests.

**Notes.** The helper also registered its temp-folder cleanup on that throwaway instance, so the folder was never removed; moving it into an XCTestCase extension fixes both.

## Evidence

- Merged into master (1f7d3d0, Language pack tests compile on Windows).
- Mac: `swift test` for LanguagePackEngineTests and the five language classes, 42 tests, 0 failures; no temp pack folders left after a run.
- Windows CI run 40185205126 on master (which includes the fix): success, 116 tests, 0 failures. Run 40184995842 for the merge itself was cancelled by a newer push, not failed.
