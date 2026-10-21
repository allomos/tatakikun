**Outcome.** When the user types Chinese or Japanese and picks the result by hand, and the committed result is 2 to 4 characters long, Tatakikun records it as a custom word under the reading typed. Typing that reading again offers the word directly, near the top.

**Done means.**
- Chinese: type a reading whose intended word is not offered as one candidate, build it by picking the parts by hand (e.g. two picks of 2 characters each). Typing the same reading again shows the 2–4 character result as a single candidate, near the top.
- Japanese: the same, with romaji input and a kana/kanji result.
- Results of 1 character or more than 4 characters are not recorded as custom words.
- Committing the first candidate without a hand pick records nothing new.
- Custom words survive restarting the input method.
- Unit tests cover Chinese and Japanese, 2 and 4 characters, and the 1- and 5-character cases.

**Notes.**
- Related: A02-05 (remembers picked candidates and ranks them higher). This task adds words that were not in the dictionary as one entry.
- Routine choices for whoever works it (record with `alm ai-decided`): what counts as a hand pick (default: choosing a candidate other than the first, or building the result from more than one pick), whether a custom word also has its consonant-only abbreviation (A02-06), and where custom words are stored (default: alongside A02-05's learning data).
