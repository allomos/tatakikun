#!/bin/sh
# Builds build/Tatakikun.app (the input method and its icon) and the language packs in build/packs.
# The dictionaries are not in the app: each language is a pack the installer puts next to it.
# Usage: scripts/build.sh [zh,ja,en]   (the packs to build; all by default)
set -e
cd "$(dirname "$0")/.."
swift build -c release
scripts/build-packs.sh "${1:-zh,ja,en}"
APP=build/Tatakikun.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Tatakikun "$APP/Contents/MacOS/"
cp App/Info.plist "$APP/Contents/"
cp -R App/Resources/ "$APP/Contents/Resources/"   # localized names of the input source
swift scripts/make-icon.swift "$APP/Contents/Resources/Tatakikun.tiff"
codesign --force --sign - "$APP"
echo "Built $APP"
