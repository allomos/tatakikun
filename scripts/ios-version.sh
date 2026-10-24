#!/bin/sh
# An Xcode build phase of the iOS app and keyboard: writes the Mac app's version (App/Info.plist)
# into the built Info.plist, so the iPhone app goes with the same release, as the APK does
# (0.6.10, build number 610).
set -e
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SRCROOT/../App/Info.plist")
BUILD=$(echo "$VERSION" | awk -F. '{ print $1 * 10000 + $2 * 100 + $3 }')
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" \
    "$TARGET_BUILD_DIR/$INFOPLIST_PATH"
