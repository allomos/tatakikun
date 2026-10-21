#!/bin/sh
# Builds the engine for Android as one shared library, build/android/<abi>/libTatakikunEngine.so,
# next to the Swift runtime libraries it loads (stripped), and prints their size.
#   scripts/build-android.sh [arm64-v8a|x86_64]      (arm64-v8a by default)
# Needs the open-source Swift toolchain that matches the Swift SDK for Android (swift.org, here
# 6.3.3 in ~/Library/Developer/Toolchains), that SDK (`swift sdk install …_android.artifactbundle…`)
# and the Android NDK it was set up with (ANDROID_NDK_HOME, or the newest in ~/Library/Android/sdk/ndk).
set -e
cd "$(dirname "$0")/.."
ABI=${1:-arm64-v8a}
case $ABI in
    arm64-v8a) ARCH=aarch64 ;;
    x86_64) ARCH=x86_64 ;;
    *) echo "unknown ABI $ABI" >&2; exit 1 ;;
esac
SWIFT=${TATAKIKUN_SWIFT:-$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swift}
SDK=$("$SWIFT" sdk list | grep -m1 android)
SDKDIR=$HOME/Library/org.swift.swiftpm/swift-sdks/$SDK.artifactbundle/swift-android
NDK=${ANDROID_NDK_HOME:-$(ls -d "$HOME"/Library/Android/sdk/ndk/* | sort -V | tail -1)}
BIN=$(ls -d "$NDK"/toolchains/llvm/prebuilt/*/bin | head -1)

"$SWIFT" build --swift-sdk $ARCH-unknown-linux-android28 -c release --product TatakikunEngine
OUT=build/android/$ABI
rm -rf "$OUT" && mkdir -p "$OUT"
cp .build/$ARCH-unknown-linux-android28/release/libTatakikunEngine.so "$OUT/"

# Every library it loads, followed through (the system's own are on the phone already).
LIBS="$SDKDIR/swift-resources/usr/lib/swift-$ARCH/android $(dirname "$(find "$NDK" -path "*$ARCH-linux-android/libc++_shared.so" | head -1)")"
todo=libTatakikunEngine.so
while [ -n "$todo" ]; do
    set -- $todo; lib=$1; shift; todo="$*"
    for n in $("$BIN/llvm-readelf" -d "$OUT/$lib" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
        [ -f "$OUT/$n" ] && continue
        for d in $LIBS; do
            if [ -f "$d/$n" ]; then cp "$d/$n" "$OUT/"; todo="$todo $n"; break; fi
        done
    done
done
for f in "$OUT"/*.so; do "$BIN/llvm-strip" --strip-unneeded "$f"; done
ls -l "$OUT"/*.so | awk '{ t += $5; printf "%8.2f MB  %s\n", $5 / 1e6, $9 } END { printf "%8.2f MB  total\n", t / 1e6 }'
