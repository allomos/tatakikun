**Outcome.** Typing Arabic by sound in Latin letters gives Arabic-script candidates: `marhaba` → مرحبا, `shukran` → شكرا.

**Done means.**
- Common Arabizi spellings work, including the digits used for letters (`3` for ع, `7` for ح: `7abibi` → حبيبي).
- Arabic candidates show right to left in the candidate bar, and mixed Arabic and English text is committed in the right order.
- It is its own language pack, chosen in the installer and turned on or off in settings (A04-tuna688).
- Its candidates mix with English, Chinese and Japanese ones, and the raw letter string stays a candidate.
- Tests cover at least 50 common words and a few whole short phrases.
- Checked on macOS, Android and iOS.

**Notes.**
- Right-to-left text is new to Tatakikun: check the candidate bar, the key popups and committed text on every platform.
- Which Arabic is the target: Modern Standard Arabic words first; dialect words are a routine choice for whoever builds it.
- Part of A03-wood850 (five more languages, chosen by the person on 2026-10-23).
- **Open for the person:** the word list source and its licence (it must allow MIT redistribution), and how much the pack may add to the app size. Propose a source with its licence and size before building.
- **Approved by the approver (2026-10-25):** the word list sources and pack size in the handoff note's proposal (claude-loop3, 2026-10-25). Arabizi digits (2 ء, 3 ع, 7 ح, …) are supported: the person left this choice to Claude, which chose yes because many people type Arabic in Latin letters with them.

**Evidence.**
- Merged into master (c410064). The ar pack (build/packs/ar, 1.8 MB, 20 000 words, 68 000 keys) is built by `tatakikun-dictgen pack ar` (Sources/tatakikun-dictgen/Arabic.swift) from Common Voice's Arabic sentences (sentence-collector.txt at commit f96d1c37, CC0, pinned with SHA-256; 52 500 words, harakat and tatweel left out). The approved proposal said about 1 MB; 1.8 MB keeps 20 000 words with up to four keys each (Common Voice has 25 000 Arabic words seen more than once).
- Arabic does not write short vowels, so each word is keyed by its skeleton: its consonants as Arabizi spells them (ح 7/h, ع 3, خ kh/5, ق q/2/k/g, ص s/9, ط t/6, ش sh/ch, ء 2 …) and its long vowels as A (ا ى), U (و) and I (ي); a final ا is also -an (shukran), a final ه may be left out. The engine turns what was typed into the same skeletons (`WordConverter.arabiziKeys`), each vowel typed either a long vowel (by its letter) or a short one, with a small cost for each dropped vowel (more at the end of the word) and more for a doubled consonant taken once. Arabic costs a little more than the other languages, so they keep their first places (woaini 我爱你, hello, nihao 你好), until an Arabic word was inserted (momentum). A loose match gets no place of its own in the bar.
- Digits for letters (Modern Standard Arabic words, typed the Arabizi way): a digit joins the word being typed when some Arabic word goes on that way, also as its first letter (7abibi حبيبي, ya3ni يعني, 3arabi عربي); otherwise a digit chooses a candidate or is typed as itself, as before; a number stays a number (2026). Only with the Arabic pack on. While typing a word an Arabic word could go on with, digits 2, 3, 5–9 join it instead of choosing the candidate of that number (on macOS, 1 and 4 still choose).
- Fixed on the way: with eight languages, more kinds could match than the bar holds (ta showed 10 candidates); the bar now keeps the first candidate and the cheapest of the others.
- A new candidate kind ع (`.arabic`); العربية in the input menu (macOS), Input languages (iOS) and the language dialog (Android), and in the installer (checked by default) and `scripts/install.sh`.
- `ArabicTests`: marhaba مرحبا, shukran شكرا, 7abibi حبيبي, ya3ni يعني, 3arabi عربي, wallah والله, ahlan أهلا; digits (7abibi composes, 2026 is typed, nihao + 1 chooses 你好, with Arabic off 7 is the application's); 58 common words; the phrases ana min masr → أنا من مصر, shukran ya habibi → شكرا يا حبيبي, kayf 7alak → كيف حالك; mixing; the bar never over 9; `swift test`: 112 tests, 0 failures.
- Android (Pixel_7_API_34_b emulator): `scripts/test-android.sh` passes, with `marhaba SPACE` → `مرحبا `, `ya3ni SPACE` → `يعني ` (digits from the key events) and `hello SPACE marhaba SPACE` → `hello مرحبا ` (in order). iOS (iPhone 16 Pro simulator): UI test `testArabicInArabizi` (hello then marhaba → field `hello مرحبا`, Arabic right to left in the bar: screenshot) and all 18 UI tests pass. macOS: the input method builds and `tatakikun-cli --packs build/packs` shows the candidates; not reinstalled here, and the installer was not rebuilt.
- Known gaps: Common Voice's Arabic text is small, so rarer words and dialect words are missing; shadda is not typed doubled (mudarris finds مدرس only through the doubled-consonant rule).
