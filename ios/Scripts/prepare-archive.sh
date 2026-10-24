#!/bin/sh
# MediaPipe Tasks 1.0.1 binary bundles omit the version keys required by App Store validation.
# Patch only the built archive, never the package cache. Re-sign each changed bundle.
set -eu
archive_path=${1:?Pass the xcarchive path}
signing_identity=${2:?Pass your Apple Development signing identity or certificate SHA-1}
app_path="$archive_path/Products/Applications/InvisibleViolin.app"
[ -d "$app_path" ] || { echo 'InvisibleViolin archive app not found' >&2; exit 1; }
for module in Common Audio Text Vision; do
    framework_path="$app_path/Frameworks/MediaPipeTasks$module.framework"
    [ -d "$framework_path" ] || { echo "Missing expected MediaPipeTasks$module framework" >&2; exit 1; }
    plist_path="$framework_path/Info.plist"
    if ! /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 1.0.1' "$plist_path"
    fi
    if ! /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist_path" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 1' "$plist_path"
    fi
    /usr/bin/codesign --force --sign "$signing_identity" --preserve-metadata=identifier,entitlements,flags "$framework_path"
done
/usr/bin/codesign --force --sign "$signing_identity" --preserve-metadata=identifier,entitlements,flags "$app_path"
/usr/bin/codesign --verify --deep --strict "$app_path"
echo 'Archive framework versions and code signatures verified.'
