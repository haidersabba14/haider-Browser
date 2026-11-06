#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
artifact_dir="${RUNNER_TEMP:-$PWD/build}/madar-artifacts"
mkdir -p "$artifact_dir"

xcodebuild -project Madar.xcodeproj -scheme Madar -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build-device CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build \
  > "$artifact_dir/device-build.log" 2>&1 || {
    tail -n 120 "$artifact_dir/device-build.log"
    exit 1
  }

app_path="$PWD/build-device/Build/Products/Release-iphoneos/Madar.app"
test -f "$app_path/Madar"
test -f "$app_path/web/client.js"
test -f "$app_path/web/dashboard.html"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")" = 'com.madar.analytics'
file "$app_path/Madar" | tee "$artifact_dir/binary-info.txt"

mkdir -p package/Payload
cp -R "$app_path" package/Payload/
(
  cd package
  /usr/bin/zip -qr "$artifact_dir/Madar-unsigned.ipa" Payload
)
unzip -t "$artifact_dir/Madar-unsigned.ipa" > "$artifact_dir/package-check.txt"
(
  cd "$artifact_dir"
  shasum -a 256 Madar-unsigned.ipa > SHA256SUMS.txt
)
cat > "$artifact_dir/INSTALL.txt" <<'TEXT'
Madar / مدار

This IPA was built for physical iOS devices without an Apple signing identity.
It must be signed with a valid certificate and provisioning method before installation.
It is not an App Store or TestFlight distribution package.

The app uses the password previously configured by its owner and reads the public
GitHub projects belonging to haidersabba14. It contains 136 developer tools.
GitHub release download counts are not unique users or installations.
TEXT
echo "IPA built and validated: $artifact_dir/Madar-unsigned.ipa"
