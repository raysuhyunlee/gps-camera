#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IOS="$ROOT/ios"
APP="$IOS/build/direct-capture/Build/Products/Debug-iphonesimulator/gpscamera.app"
RAW="$IOS/fastlane/screenshots_raw"
BUNDLE_ID="com.raysuhyunlee.gpscamera"

locales=(
  en-US ko ja zh-Hans zh-Hant es-ES pt-BR de-DE fr-FR it ru nl-NL sv da no fi
  pl tr ar-SA he hi th vi id ms cs el uk ro hu
)
devices=("iPhone 17 Pro Max" "iPad Pro 13-inch (M5)")
screens=("01Main:main:6" "02Settings:settings:4" "03Gallery:gallery:4")

device_udid() {
  xcrun simctl list devices available -j | ruby -rjson -e '
    name = ARGV.fetch(0)
    devices = JSON.parse(STDIN.read).fetch("devices").values.flatten
    match = devices.find { |device| device["name"] == name && device["isAvailable"] }
    abort("simulator not found: #{name}") unless match
    puts match.fetch("udid")
  ' "$1"
}

rm -rf "$RAW"
mkdir -p "$RAW"

xcodebuild \
  -project "$IOS/gpscamera.xcodeproj" \
  -scheme gpscamera \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  -configuration Debug \
  -derivedDataPath "$IOS/build/direct-capture" \
  build CODE_SIGNING_ALLOWED=NO -quiet

for device in "${devices[@]}"; do
  udid=$(device_udid "$device")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  xcrun simctl privacy "$udid" grant camera "$BUNDLE_ID"
  xcrun simctl privacy "$udid" grant photos "$BUNDLE_ID"
  xcrun simctl privacy "$udid" grant location "$BUNDLE_ID"
  xcrun simctl status_bar "$udid" override \
    --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4

  for locale in "${locales[@]}"; do
    mkdir -p "$RAW/$locale"
    for entry in "${screens[@]}"; do
      IFS=: read -r file screen wait_seconds <<< "$entry"
      xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" \
        -ScreenshotDemo 1 -Scene new-york -ScreenshotPro 1 \
        -ScreenshotLocale "$locale" -ScreenshotScreen "$screen" >/dev/null
      sleep "$wait_seconds"
      xcrun simctl io "$udid" screenshot "$RAW/$locale/$device-$file.png" >/dev/null
    done
  done

  xcrun simctl status_bar "$udid" clear || true
  xcrun simctl shutdown "$udid" || true
done

echo "Captured ${#locales[@]} locales for ${#devices[@]} devices."
