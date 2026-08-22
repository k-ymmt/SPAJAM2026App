#!/usr/bin/env bash
# Firebase の GoogleService-Info.plist を CLI で取得して配置する(gitignore 済み)。
# Requires: Firebase CLI (`firebase login` 済み、spajam2026-app への権限)
set -euo pipefail
cd "$(dirname "$0")/.."
firebase apps:sdkconfig ios 1:237746288839:ios:495fc9c014db596395e6e2 --project spajam2026-app 2>/dev/null \
  | sed -n '/<?xml/,$p' > SPAJAM2026App/GoogleService-Info.plist
echo "wrote SPAJAM2026App/GoogleService-Info.plist"
