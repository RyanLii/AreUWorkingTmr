#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DERIVED_DATA="${IOS_DERIVED_DATA:-/tmp/awt-ios-dd}"
WATCH_DERIVED_DATA="${WATCH_DERIVED_DATA:-/tmp/awt-watch-dd}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/artifacts}"
TIMEOUT_BIN="${TIMEOUT_BIN:-$(command -v timeout || true)}"
IOS_TEST_DESTINATION="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15,OS=17.0.1}"

IOS_26_UDID="42E9D9EE-90E4-4DFD-9149-D9AD6EF81FFA" # iPhone 17 (iOS 26.2)
IOS_17_UDID="5C52D3FE-32F9-4D14-9FD9-45F67A33B57C" # iPhone 15 (iOS 17.0)
WATCH_26_UDID="EF53460F-9860-486A-8712-E07865D0936D" # Apple Watch Series 11 (46mm)

IOS_BUNDLE_ID="com.ryanlee.AreUWorkingTmr"
WATCH_BUNDLE_ID="com.ryanlee.AreUWorkingTmr.watch"

if [[ -z "$TIMEOUT_BIN" ]]; then
  echo "error: 'timeout' command not found. Install coreutils and ensure 'timeout' is in PATH."
  exit 1
fi

log() {
  printf "\n[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

run_with_timeout() {
  local seconds="$1"
  shift
  "$TIMEOUT_BIN" "$seconds" "$@"
}

boot_and_wait() {
  local udid="$1"
  local boot_timeout="$2"

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  run_with_timeout "$boot_timeout" xcrun simctl bootstatus "$udid" -b
}

install_with_retry() {
  local udid="$1"
  local app_path="$2"
  local boot_timeout="$3"
  local install_timeout="$4"

  for attempt in 1 2; do
    if boot_and_wait "$udid" "$boot_timeout" && run_with_timeout "$install_timeout" xcrun simctl install "$udid" "$app_path"; then
      return 0
    fi

    if [[ "$attempt" -eq 1 ]]; then
      log "Install failed for $udid, erasing simulator and retrying once"
      xcrun simctl shutdown "$udid" || true
      xcrun simctl erase "$udid" || true
    fi
  done

  return 1
}

capture_screenshot() {
  local udid="$1"
  local app_path="$2"
  local bundle_id="$3"
  local boot_timeout="$4"
  local install_timeout="$5"
  local output_path="$6"

  install_with_retry "$udid" "$app_path" "$boot_timeout" "$install_timeout"
  xcrun simctl launch "$udid" "$bundle_id" >/dev/null || true
  sleep 2
  run_with_timeout 30 xcrun simctl io "$udid" screenshot "$output_path"
  ls -lh "$output_path"
}

main() {
  cd "$ROOT_DIR"
  mkdir -p "$ARTIFACTS_DIR"

  log "Generating Xcode project"
  xcodegen generate >/dev/null

  log "Running core tests"
  swift test

  log "Building iOS app"
  xcodebuild -project AreUWorkingTmr.xcodeproj \
    -scheme AreUWorkingTmr \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    build CODE_SIGNING_ALLOWED=NO >/dev/null

  log "Building watchOS app"
  xcodebuild -project AreUWorkingTmr.xcodeproj \
    -scheme AreUWorkingTmrWatch \
    -destination 'generic/platform=watchOS Simulator' \
    -derivedDataPath "$WATCH_DERIVED_DATA" \
    build CODE_SIGNING_ALLOWED=NO >/dev/null

  log "Running Xcode iOS test bundle"
  xcodebuild -project AreUWorkingTmr.xcodeproj \
    -scheme AreUWorkingTmr \
    -destination "$IOS_TEST_DESTINATION" \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    test CODE_SIGNING_ALLOWED=NO >/dev/null

  local ios_app_path="$IOS_DERIVED_DATA/Build/Products/Debug-iphonesimulator/AreUWorkingTmr.app"
  local watch_app_path="$WATCH_DERIVED_DATA/Build/Products/Debug-watchsimulator/AreUWorkingTmrWatch.app"

  log "Capturing iOS 17 screenshot"
  capture_screenshot "$IOS_17_UDID" "$ios_app_path" "$IOS_BUNDLE_ID" 240 120 "$ARTIFACTS_DIR/ios-17-home.png"

  log "Capturing iOS 26 screenshot"
  capture_screenshot "$IOS_26_UDID" "$ios_app_path" "$IOS_BUNDLE_ID" 900 120 "$ARTIFACTS_DIR/ios-26-home.png"

  log "Capturing watchOS 26 screenshot"
  capture_screenshot "$WATCH_26_UDID" "$watch_app_path" "$WATCH_BUNDLE_ID" 300 120 "$ARTIFACTS_DIR/watch-26-home.png"

  log "Smoke run complete"
}

main "$@"
