#!/bin/sh
# Builds the language packs into build/packs/<zh|ja|en|es|fr|hi|bn|ar>: downloads the pinned open data
# (scripts/fetch-sources.sh), then combines it with the base dictionaries in build/dict.
# Usage: scripts/build-packs.sh [zh,ja,en,es,fr,hi,bn,ar]
set -e
cd "$(dirname "$0")/.."
LANGS=${1:-zh,ja,en,es,fr,hi,bn,ar}
swift build -c release --product tatakikun-dictgen
if [ ! -f build/dict/zh.tsv ] || [ ! -f build/dict/ja.tsv ]; then
    echo "Generating the base dictionaries from this Mac's ICU data (about a minute)..."
    .build/release/tatakikun-dictgen build/dict
elif [ ! -f build/dict/zh.ttkd ] || [ ! -f build/dict/ja.ttkd ] || [ build/dict/zh.tsv -nt build/dict/zh.ttkd ]; then
    .build/release/tatakikun-dictgen --compile build/dict
fi
scripts/fetch-sources.sh "$LANGS"
for lang in $(echo "$LANGS" | tr ',' ' '); do
    .build/release/tatakikun-dictgen pack "$lang" build/dict build/sources build/packs
done
echo "Packs ready in build/packs"
