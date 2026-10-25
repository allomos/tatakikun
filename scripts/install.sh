#!/bin/sh
# Installs build/Tatakikun.app into ~/Library/Input Methods and the chosen language packs into
# ~/Library/Application Support/Tatakikun/Packs (packs not chosen are removed), installs a login item
# that starts Tatakikun at login, and starts it now. For an installer with check boxes, see scripts/make-installer.sh.
# Usage: scripts/install.sh [zh,ja,en,es]   (all by default)
set -e
cd "$(dirname "$0")/.."
LANGS=${1:-zh,ja,en,es}
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
HOME_DIR=$HOME
# Start Tatakikun at login: macOS only starts an input method when a text field asks for it, and
# right after login that request is lost, so typing did nothing until the user changed windows.
# It shows under System Settings > General > Login Items as a background item, where it can be turned off.
AGENTS="$HOME_DIR/Library/LaunchAgents"
AGENT="$AGENTS/com.tatakikun.inputmethod.Tatakikun.plist"
mkdir -p "$AGENTS"
cat > "$AGENT" <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.tatakikun.inputmethod.Tatakikun</string>
	<key>ProgramArguments</key>
	<array>
		<string>$HOME_DIR/Library/Input Methods/Tatakikun.app/Contents/MacOS/Tatakikun</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>AssociatedBundleIdentifiers</key>
	<string>com.tatakikun.inputmethod.Tatakikun</string>
</dict>
</plist>
EOT
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null || true
for lang in zh ja en es; do
    rm -rf "$PACKS/$lang"
    case ",$LANGS," in *,$lang,*) cp -R build/packs/$lang "$PACKS/$lang" ;; esac
done
echo "Installed $DEST/Tatakikun.app with language packs: $LANGS"
echo "First time: System Settings > Keyboard > Text Input > Input Sources > Edit… > + > 简体中文 (Chinese, Simplified) > Tatakikun."
echo "You may need to log out and back in before it appears in the list."
# Reinstalling ended the running Tatakikun. Native apps reconnect to the new one by themselves;
# Electron apps (VS Code, Slack…) stay attached to the old one: Tatakikun shows in the menu bar
# but keys do nothing there until the app is quit and reopened.
ELECTRON=$(ps -axo comm= | sed -n 's|^\(/.*\.app\)/Contents/MacOS/.*|\1|p' | sort -u | while read -r app; do
    [ -d "$app/Contents/Frameworks/Electron Framework.framework" ] && basename "$app" .app
done | paste -sd, - | sed 's/,/, /g')
echo "Electron apps (VS Code, Slack…) that were open: quit them with ⌘Q and reopen them, or Tatakikun types nothing there."
echo "已经打开的 Electron 应用(VS Code、Slack 等)要用 ⌘Q 完全退出再打开,Tatakikun 才能在里面输入。"
[ -z "$ELECTRON" ] || echo "Running now / 正在运行: $ELECTRON"
