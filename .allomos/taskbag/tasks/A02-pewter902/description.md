**Outcome.** The Windows CI run on master (.github/workflows/windows.yml) passes again. It has failed on every push since the Spanish pack: the five language test files (Spanish, French, Hindi, Bengali, Arabic) call `LanguagePackEngineTests()`, and XCTest on Windows and Linux has no plain `init()` for a test case.

**Done means.**
- The Windows run on master passes.
- `swift test` on the Mac passes for the language pack tests.

**Notes.** The helper also registered its temp-folder cleanup on that throwaway instance, so the folder was never removed; moving it into an XCTestCase extension fixes both.
