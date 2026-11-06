#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
artifact_dir="${RUNNER_TEMP:-$PWD/build}/madar-artifacts"
mkdir -p "$artifact_dir"
xcodebuild -project Madar.xcodeproj -scheme Madar -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build-simulator CODE_SIGNING_ALLOWED=NO build \
  > "$artifact_dir/simulator-build.log" 2>&1 || {
    tail -n 100 "$artifact_dir/simulator-build.log"
    exit 1
  }
simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for v in d["devices"].values() for x in v if x["name"].startswith("iPhone")))')"
xcrun simctl boot "$simulator_id" || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" build-simulator/Build/Products/Debug-iphonesimulator/Madar.app
xcrun simctl launch "$simulator_id" com.madar.analytics | tee "$artifact_dir/simulator-launch.txt"
python3 -c 'import time; time.sleep(3)'
xcrun simctl io "$simulator_id" screenshot "$artifact_dir/simulator-login.png"
