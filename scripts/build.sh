#!/bin/sh
# Builds build/Tatakikun.app: the input method, its dictionaries and its icon.
set -e
cd "$(dirname "$0")/.."
swift build -c release
if [ ! -f build/dict/zh.tsv ] || [ ! -f build/dict/ja.tsv ]; then
    echo "Generating dictionaries from this Mac's ICU data (about a minute)..."
    .build/release/tatakikun-dictgen build/dict
fi
APP=build/Tatakikun.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/dict"
cp .build/release/Tatakikun "$APP/Contents/MacOS/"
cp App/Info.plist "$APP/Contents/"
cp build/dict/zh.tsv build/dict/ja.tsv "$APP/Contents/Resources/dict/"
swift scripts/make-icon.swift "$APP/Contents/Resources/Tatakikun.tiff"
codesign --force --sign - "$APP"
echo "Built $APP"
