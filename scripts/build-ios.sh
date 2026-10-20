#!/bin/sh
# Builds the iOS app with the Tatakikun keyboard for the simulator and runs its UI tests.
#   scripts/build-ios.sh            build
#   scripts/build-ios.sh test       build and run the UI tests on an iPhone simulator
# Needs the language packs (scripts/build.sh makes build/packs) and XcodeGen (brew install xcodegen)
# when iOS/project.yml has changed.
set -e
cd "$(dirname "$0")/.."
[ -f build/packs/zh/zh.ttkd ] || scripts/build.sh
if command -v xcodegen >/dev/null; then (cd iOS && xcodegen generate --quiet); fi
DEVICE=${TATAKIKUN_SIMULATOR:-$(xcrun simctl list devices available | grep -m1 -oE 'iPhone[^(]*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')}
ACTION=build
[ "$1" = test ] && ACTION=test
xcodebuild -project iOS/Tatakikun.xcodeproj -scheme Tatakikun -destination "id=$DEVICE" \
    -derivedDataPath build/ios -quiet $ACTION
echo "App: build/ios/Build/Products/Debug-iphonesimulator/Tatakikun.app"
echo "Install it: xcrun simctl install $DEVICE build/ios/Build/Products/Debug-iphonesimulator/Tatakikun.app"
