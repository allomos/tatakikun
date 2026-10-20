# Tatakikun

A macOS input method that reads what you type in English letters three ways at once — as an
English word, as Chinese pinyin and as Japanese romaji — and offers English, Chinese, hiragana,
katakana and Japanese kanji candidates side by side in one horizontal bar. The letters as typed
are always one of the candidates.

## Build and install

```sh
scripts/build.sh     # builds build/Tatakikun.app (first run also builds the dictionaries, ~1 min)
scripts/install.sh   # copies it to ~/Library/Input Methods
```

Then add it once: System Settings → Keyboard → Text Input → Input Sources → Edit… → + →
Chinese, Simplified (简体中文) → Tatakikun. If it is not listed yet, log out and back in.

Try it without installing: `TATAKIKUN_DICT=build/dict .build/release/Tatakikun --demo`.

## Keys

| Key | While typing |
| --- | --- |
| letters | add to the input |
| Space | insert the highlighted candidate (the first one unless moved) |
| Return | insert the letters exactly as typed |
| 1–9 | insert that candidate of the highlighted row |
| ← → | move the highlight |
| ↓ or Tab | expand the bar downward into more rows (then move down a row); the rows scroll |
| ↑ | move up a row; from the first row, collapse |
| Backspace | remove the last letter |
| Esc | collapse when expanded, otherwise cancel |
| click | insert the clicked candidate |
| punctuation | insert the highlighted candidate, then the punctuation |

## Candidate order

The bar is ordered by cost (how common each word is), with two guarantees: the best candidate of
every language that matched (EN, 中, 日 kanji, あ hiragana, ア katakana) is in the bar, and so are
the letters as typed — ranked like any English word when they are one, otherwise in the last place.

Expanded rows also hold partial matches (shown in gray): words that complete what you typed
(`zhongg` → 中国, `compu` → computer, `arigat` → ありがとう), English spelling suggestions, and
words that cover only the start of the letters (`nihaoma` → 你好); choosing one of those inserts it
and keeps the remaining letters (`ma`) to go on typing. When nothing matches all the letters yet,
the bar itself shows the best partial matches.

## Dictionaries

Built on this Mac from data macOS already has: the CJK word list in ICU's data file
(`/usr/share/icu`, with word frequencies), the system's pinyin and Japanese reading transforms,
and the system English spell checker. Nothing is downloaded. `tatakikun-dictgen` writes
`build/dict/zh.tsv` and `build/dict/ja.tsv` (`reading<TAB>word<TAB>cost`).

## Development

- `swift test` — engine and key-handling tests (needs `build/dict`).
- `swift run -c release tatakikun-cli nihao ai toukyou` — print candidates.
- `.build/release/Tatakikun --snapshot <letters> out.png [dark]` — draw the candidate bar to an image.
