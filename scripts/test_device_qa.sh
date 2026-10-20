#!/usr/bin/env bash
set -euo pipefail
# A separate package and retained install protect the user's local workspace.
# Usage: ./scripts/test_device_qa.sh -d DEVICE_ID
ORG_GRADLE_PROJECT_ascentDeviceQa=true flutter test --no-pub --no-uninstall integration_test/daily_briefing_device_test.dart "$@"
