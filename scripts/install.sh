#!/bin/sh
# Installs build/Tatakikun.app into ~/Library/Input Methods and restarts it if it was running.
set -e
cd "$(dirname "$0")/.."
[ -d build/Tatakikun.app ] || scripts/build.sh
DEST="$HOME/Library/Input Methods"
mkdir -p "$DEST"
pkill -x Tatakikun 2>/dev/null || true
rm -rf "$DEST/Tatakikun.app"
cp -R build/Tatakikun.app "$DEST/"
echo "Installed to $DEST/Tatakikun.app"
echo "First time: System Settings > Keyboard > Text Input > Input Sources > Edit… > + > 简体中文 (Chinese, Simplified) > Tatakikun."
echo "You may need to log out and back in before it appears in the list."
