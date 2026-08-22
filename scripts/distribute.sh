#!/usr/bin/env bash
# Archive the app and upload it to Firebase App Distribution.
#
# Usage: scripts/distribute.sh [release notes]
# Requires: Xcode, Firebase CLI (`firebase login` done), testers/groups set in the console.
set -euo pipefail

cd "$(dirname "$0")/.."

FIREBASE_PROJECT="spajam2026-app"
FIREBASE_APP_ID="1:237746288839:ios:495fc9c014db596395e6e2"
SCHEME="SPAJAM2026App"
BUILD_DIR="build/distribution"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
NOTES="${1:-$(git log -1 --pretty=%s) ($(git rev-parse --short HEAD))}"

rm -rf "$BUILD_DIR"

xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates archive -quiet

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates -quiet

firebase appdistribution:distribute "$EXPORT_DIR/$SCHEME.ipa" \
  --app "$FIREBASE_APP_ID" --project "$FIREBASE_PROJECT" \
  --release-notes "$NOTES" ${FIREBASE_TESTER_GROUPS:+--groups "$FIREBASE_TESTER_GROUPS"}
