#!/bin/sh
# Renders the app icon from docs/icon/*.svg into the files each platform builds with, which are
# checked in (so the builds need none of these tools):
#   App/Resources/AppIcon.icns                          macOS app (Finder, login items)
#   iOS/App/Assets.xcassets/AppIcon.appiconset          iOS app (full bleed, no transparency)
#   android/.../mipmap-*/ic_launcher_foreground.png     Android adaptive icon foreground
# The Android background (drawable/ic_launcher_background.xml) and monochrome layer
# (drawable/ic_launcher_monochrome.xml) are vectors kept by hand to match the SVGs.
# The menu bar icon is separate: scripts/make-icon.swift.
# Needs rsvg-convert and ImageMagick (brew install librsvg imagemagick). Usage: scripts/make-app-icons.sh
set -e
cd "$(dirname "$0")/.."
ICON=docs/icon/tatakikun-icon.svg
FULL=docs/icon/tatakikun-icon-fullbleed.svg
FG=docs/icon/tatakikun-icon-android-foreground.svg
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Full bleed: the same drawing without the macOS margin and corner rounding (iOS and Android mask it).
sed -e 's|viewBox="0 0 1024 1024"|viewBox="100 100 824 824"|' -e 's|rx="185"|rx="0"|' "$ICON" > "$FULL"

# macOS
SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
for s in 16 32 128 256 512; do
    rsvg-convert -w $s -h $s "$ICON" -o "$SET/icon_${s}x${s}.png"
    rsvg-convert -w $((s * 2)) -h $((s * 2)) "$ICON" -o "$SET/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$SET" -o App/Resources/AppIcon.icns

# iOS: one 1024 image, opaque
APPICON=iOS/App/Assets.xcassets/AppIcon.appiconset
mkdir -p "$APPICON"
rsvg-convert -w 1024 -h 1024 "$FULL" | magick - -background '#2a9d8f' -alpha remove -alpha off "$APPICON/AppIcon.png"

# Android: 108dp foreground at each density
RES=android/app/src/main/res
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
    mkdir -p "$RES/mipmap-${d%%:*}"
    rsvg-convert -w "${d##*:}" -h "${d##*:}" "$FG" -o "$RES/mipmap-${d%%:*}/ic_launcher_foreground.png"
done

# Previews in docs/icon
rsvg-convert -w 1024 -h 1024 "$ICON" -o docs/icon/tatakikun-icon-1024.png
cp "$APPICON/AppIcon.png" docs/icon/tatakikun-icon-ios-1024.png
rsvg-convert -w 512 -h 512 "$FULL" -o docs/icon/tatakikun-icon-play-512.png
echo "App icons rendered"
