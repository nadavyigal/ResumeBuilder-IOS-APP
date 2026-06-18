#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ResumeBuilder IOS APP.xcodeproj"
SCHEME="ResumeBuilder IOS APP"
BUNDLE_ID="Resumebuilder-IOS.ResumeBuilder-IOS-APP"
DERIVED_DATA="${DERIVED_DATA:-/var/tmp/resumely-screenshot-derived}"
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/ResumeBuilder IOS APP.app"
OUTPUT="$ROOT/dist/app-store-screenshots/app-store-v1"

IPHONE_ID="${IPHONE_ID:-8A728F41-76C5-420D-82E6-3AE1A383A13E}"
IPAD_ID="${IPAD_ID:-B2017D4B-BC89-4A2D-AB81-EF057550135D}"

names=(
  tailor
  blockers
  ai-edits
  score-lift
  manual-edit
  templates
  export
  expert
  cover-letter
  submit-package
)

mkdir -p "$OUTPUT/iphone-6.5-1242x2688" "$OUTPUT/ipad-13"
rm -f "$OUTPUT/iphone-6.5-1242x2688/"*.png(N) "$OUTPUT/ipad-13/"*.png(N)

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$IPHONE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  build >/var/tmp/resumely-screenshot-build.log

capture_set() {
  local device_id="$1"
  local destination="$2"

  xcrun simctl boot "$device_id" 2>/dev/null || true
  open -a Simulator
  xcrun simctl bootstatus "$device_id" -b
  xcrun simctl status_bar "$device_id" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4
  xcrun simctl install "$device_id" "$APP"

  for slot in {1..10}; do
    local number
    number=$(printf "%02d" "$slot")
    local output="$destination/$number-${names[$slot]}.png"

    xcrun simctl terminate "$device_id" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$device_id" "$BUNDLE_ID" \
      --marketing-screenshot \
      --screenshot-slot "$slot" >/dev/null
    sleep 5
    xcrun simctl io "$device_id" screenshot "$output" >/dev/null
    echo "Captured $output"
  done
}

capture_set "$IPHONE_ID" "$OUTPUT/iphone-6.5-1242x2688"
capture_set "$IPAD_ID" "$OUTPUT/ipad-13"

python3 "$ROOT/scripts/normalize-app-store-screenshots.py" "$OUTPUT"
"$ROOT/scripts/validate-app-store-screenshots.sh" "$OUTPUT"
