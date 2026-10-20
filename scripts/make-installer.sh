#!/bin/sh
# Builds build/Tatakikun-<version>.pkg: a macOS installer for the input method (for Apple silicon
# and Intel Macs) with a check box for each language pack. It installs into the current user's
# Library (no administrator password): ~/Library/Input Methods/Tatakikun.app and
# ~/Library/Application Support/Tatakikun/Packs/<zh|ja|en>. Packs left unchecked are removed.
# The package is not signed with an Apple Developer ID: see README for opening it.
set -e
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" App/Info.plist)
OUT=build/installer
rm -rf "$OUT"
mkdir -p "$OUT/packages" "$OUT/resources"

# The app, for both architectures when this Mac can build them.
scripts/build.sh
if swift build -c release --arch arm64 --arch x86_64 --product Tatakikun >/dev/null 2>&1; then
    BIN="$(swift build -c release --arch arm64 --arch x86_64 --product Tatakikun --show-bin-path)/Tatakikun"
    cp "$BIN" build/Tatakikun.app/Contents/MacOS/Tatakikun
    codesign --force --sign - build/Tatakikun.app
    ARCHS="arm64,x86_64"
else
    echo "Universal build failed; the installer is for this Mac's architecture only." >&2
    ARCHS=$(uname -m)
fi

# The input method: never relocated to where an older copy happens to be.
mkdir -p "$OUT/root-app"
cp -R build/Tatakikun.app "$OUT/root-app/"
pkgbuild --analyze --root "$OUT/root-app" "$OUT/app.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$OUT/app.plist"
pkgbuild --root "$OUT/root-app" --component-plist "$OUT/app.plist" --install-location "/Library/Input Methods" \
    --identifier com.tatakikun.inputmethod.Tatakikun --version "$VERSION" \
    --scripts App/Installer/scripts "$OUT/packages/app.pkg"

# One package per language pack.
for lang in zh ja en; do
    mkdir -p "$OUT/root-$lang"
    cp -R "build/packs/$lang" "$OUT/root-$lang/$lang"
    pkgbuild --root "$OUT/root-$lang" --install-location "/Library/Application Support/Tatakikun/Packs" \
        --identifier "com.tatakikun.pack.$lang" --version "$VERSION" "$OUT/packages/$lang.pkg"
done

# Welcome text and choice names in English, Chinese and Japanese; the license of Tatakikun and of
# the data in each pack.
cp -R App/Installer/Resources/ "$OUT/resources/"
for lproj in "$OUT"/resources/*.lproj; do
    {
        cat LICENSE
        for lang in zh ja en; do printf '\n\n'; cat "build/packs/$lang/LICENSE.txt"; done
    } > "$lproj/LICENSE.txt"
done
sed -e "s/VERSION/$VERSION/g" -e "s/HOST_ARCHITECTURES/$ARCHS/" App/Installer/Distribution.xml > "$OUT/Distribution.xml"

PKG="build/Tatakikun-$VERSION.pkg"
productbuild --distribution "$OUT/Distribution.xml" --resources "$OUT/resources" --package-path "$OUT/packages" "$PKG"
echo "Built $PKG ($(du -h "$PKG" | cut -f1)) for $ARCHS"
