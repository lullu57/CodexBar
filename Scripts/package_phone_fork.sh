#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

export CODEXBAR_SIGNING=identity
export APP_IDENTITY="Apple Development: Liam Scicluna (6L76QS2775)"
export APP_TEAM_ID="5B5L242CU5"
export CODEXBAR_APP_NAME="CodexBar Phone"
export CODEXBAR_APP_FILENAME="CodexBar Phone.app"
export CODEXBAR_BUNDLE_ID="com.ganni.codexbarphone"
export CODEXBAR_WIDGET_BUNDLE_ID="com.ganni.codexbarphone.widget"
export CODEXBAR_APP_GROUP_ID="5B5L242CU5.com.ganni.codexbarphone"
export CODEXBAR_KEYCHAIN_SERVICE="com.ganni.codexbarphone.cache"
export CODEXBAR_LOG_SUBSYSTEM="com.ganni.codexbarphone"
export CODEXBAR_AUTO_CHECKS=false
export CODEXBAR_FEED_URL=""

exec "$ROOT/Scripts/package_app.sh" "${1:-release}"
