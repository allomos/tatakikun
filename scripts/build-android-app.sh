#!/bin/sh
# Builds the Android app with the Tatakikun keyboard: android/app/build/outputs/apk/debug/app-debug.apk.
#   scripts/build-android-app.sh            build
#   scripts/build-android-app.sh install    and install it on the running emulator or connected phone
#   scripts/build-android-app.sh release    signed release build: build/Tatakikun-X.Y.Z-android.apk and .sha256
#     (the key: ~/.config/tatakikun/android-signing.properties, or $TATAKIKUN_ANDROID_SIGNING)
# Builds the engine first (scripts/build-android.sh: the Swift toolchain and Swift SDK for Android),
# then puts it and the language packs (build/packs, from scripts/build.sh) into the app.
set -e
cd "$(dirname "$0")/.."
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
export JAVA_HOME=${JAVA_HOME:-"/Applications/Android Studio.app/Contents/jbr/Contents/Home"}
[ -f build/packs/zh/zh.ttkd ] || scripts/build.sh

scripts/build-android.sh arm64-v8a
APP=android/app/src/main
rm -rf $APP/jniLibs $APP/assets/packs
mkdir -p $APP/jniLibs/arm64-v8a $APP/assets/packs
cp build/android/arm64-v8a/*.so $APP/jniLibs/arm64-v8a/
# libc++_shared.so also comes from the NDK through CMake; one copy is enough.
rm -f $APP/jniLibs/arm64-v8a/libc++_shared.so
for lang in zh ja en es; do cp -R build/packs/$lang $APP/assets/packs/; done

if [ "$1" = release ]; then
    SIGNING=${TATAKIKUN_ANDROID_SIGNING:-$HOME/.config/tatakikun/android-signing.properties}
    [ -f "$SIGNING" ] || { echo "No signing key: $SIGNING" >&2; exit 1; }
    (cd android && ./gradlew --quiet assembleRelease)
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" App/Info.plist)
    APK=build/Tatakikun-$VERSION-android.apk
    cp android/app/build/outputs/apk/release/app-release.apk $APK
    (cd build && shasum -a 256 $(basename $APK) > $(basename $APK).sha256)
    "$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --print-certs $APK | head -2
    ls -l $APK | awk '{ printf "%s: %.1f MB\n", $9, $5 / 1e6 }'
    exit
fi

(cd android && ./gradlew --quiet assembleDebug)
APK=android/app/build/outputs/apk/debug/app-debug.apk
ls -l $APK | awk '{ printf "%s: %.1f MB\n", $9, $5 / 1e6 }'
if [ "$1" = install ]; then "$ANDROID_HOME/platform-tools/adb" install -r $APK; fi
