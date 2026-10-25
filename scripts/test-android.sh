#!/bin/sh
# Tries the Tatakikun keyboard on a running Android emulator (or a connected phone with USB debugging):
# installs the app, selects the keyboard, types into the app's field with key events (the same path
# as a hardware keyboard) and checks what the field holds. Start an emulator first, for example:
#   ~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34 -no-window &
#   scripts/test-android.sh
set -e
cd "$(dirname "$0")/.."
ADB=${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb
APK=${APK:-android/app/build/outputs/apk/debug/app-debug.apk}   # APK=build/Tatakikun-X.Y.Z-android.apk tries a release
[ -f $APK ] || scripts/build-android-app.sh
$ADB wait-for-device
$ADB install -r $APK >/dev/null
IME=com.tatakikun.android/.TatakikunIME
for i in 1 2 3 4 5; do $ADB shell ime enable $IME >/dev/null 2>&1 && break; sleep 2; done
$ADB shell ime set $IME >/dev/null
# No learned words from earlier runs (a debug build lets run-as reach the app's files).
$ADB shell run-as com.tatakikun.android rm -f files/history.tsv files/custom-words.tsv 2>/dev/null || true
$ADB shell am force-stop com.tatakikun.android   # and nothing learned left in the keyboard's memory

TMP=$(mktemp -d)
field() {
    $ADB shell uiautomator dump /sdcard/tatakikun-ui.xml >/dev/null 2>&1
    $ADB pull /sdcard/tatakikun-ui.xml "$TMP/ui.xml" >/dev/null 2>&1
    python3 -c "
import re, html, sys
x = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'<node [^>]*class=\"android.widget.EditText\"[^>]*>', x)
t = re.search(r' text=\"([^\"]*)\"', m.group(0)) if m else None
print(html.unescape(t.group(1)) if t else '')" "$TMP/ui.xml"
}
focus() {   # bring the app up and tap its field, so the keyboard is up
    $ADB shell am start -W -n com.tatakikun.android/.MainActivity >/dev/null
    # Android falls back to another keyboard after the app was stopped: choose this one again
    # (only then: choosing the current keyboard again restarts it in the middle of the input).
    if [ "$($ADB shell settings get secure default_input_method | tr -d '\r')" != "$IME" ]; then
        $ADB shell ime set $IME >/dev/null
    fi
    sleep 2
    $ADB shell uiautomator dump /sdcard/tatakikun-ui.xml >/dev/null 2>&1
    $ADB pull /sdcard/tatakikun-ui.xml "$TMP/ui.xml" >/dev/null 2>&1
    xy=$(python3 -c "
import re, sys
x = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'<node [^>]*class=\"android.widget.EditText\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', x)
a, b, c, d = map(int, m.groups()); print((a + c) // 2, (b + d) // 2)" "$TMP/ui.xml")
    $ADB shell input tap $xy
    sleep 1
}
clear() {   # empty the field: select all (Ctrl+A goes past the keyboard to the field), delete
    $ADB shell input keycombination 113 29
    $ADB shell input keyevent KEYCODE_DEL
}
fails=0
check() {   # check <letters and keys> <expected field text>
    # Leaving the field ends the input: the next check starts without the last word's language.
    $ADB shell input keyevent KEYCODE_HOME
    sleep 2   # until the app is really left
    focus
    clear
    for step in $1; do
        case $step in
            SPACE|ENTER|DPAD_RIGHT|ESCAPE|DEL) $ADB shell input keyevent KEYCODE_$step ;;
            *) $ADB shell input text "$step" ;;
        esac
    done
    sleep 1
    got=$(field)
    if [ "$got" = "$2" ]; then echo "ok    $1 → $got"; else echo "FAIL  $1 → '$got', expected '$2'"; fails=$((fails + 1)); fi
}

focus
sleep 10   # the keyboard's first start copies the language packs and opens the engine
check "woaini SPACE" "我爱你"
check "nihao SPACE" "你好"
check "watashi SPACE" "私"
check "hello SPACE" "hello "
check "sute-tasu SPACE" "ステータス"
check "niyongguolema SPACE" "你用过了吗"
check "nihao SPACE ," "你好，"
check "woaini ENTER" "woaini"
check "cancion SPACE" "canción "
check "manana SPACE" "mañana "
check "francais SPACE" "français "
# → Space picks the second candidate (愛); learned, it comes first the next time.
check "ai DPAD_RIGHT SPACE ai SPACE" "愛愛"
rm -rf "$TMP"
[ $fails = 0 ] && echo "All passed" || { echo "$fails failed"; exit 1; }
