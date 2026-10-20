#!/bin/sh
# Installs build/Tatakikun.app into ~/Library/Input Methods and the chosen language packs into
# ~/Library/Application Support/Tatakikun/Packs (packs not chosen are removed), then restarts
# Tatakikun if it was running. For an installer with check boxes, see scripts/make-installer.sh.
# Usage: scripts/install.sh [zh,ja,en]   (all by default)
set -e
cd "$(dirname "$0")/.."
LANGS=${1:-zh,ja,en}
[ -d build/Tatakikun.app ] || scripts/build.sh "$LANGS"
for lang in $(echo "$LANGS" | tr ',' ' '); do
    [ -f build/packs/$lang/$lang.ttkd ] || scripts/build-packs.sh "$LANGS"
done
DEST="$HOME/Library/Input Methods"
PACKS="$HOME/Library/Application Support/Tatakikun/Packs"
mkdir -p "$DEST" "$PACKS"
pkill -x Tatakikun 2>/dev/null || true
rm -rf "$DEST/Tatakikun.app"
cp -R build/Tatakikun.app "$DEST/"
# Tell LaunchServices about the new copy: macOS starts input methods through it.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST/Tatakikun.app"
for lang in zh ja en; do
    rm -rf "$PACKS/$lang"
    case ",$LANGS," in *,$lang,*) cp -R build/packs/$lang "$PACKS/$lang" ;; esac
done
echo "Installed $DEST/Tatakikun.app with language packs: $LANGS"
echo "First time: System Settings > Keyboard > Text Input > Input Sources > Edit… > + > 简体中文 (Chinese, Simplified) > Tatakikun."
echo "You may need to log out and back in before it appears in the list."
