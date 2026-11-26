#!/usr/bin/env bash
# Runs the Sahha SDK device regression suite on a connected iPhone.
#
#   DeviceTests/run.sh                      # first connected iPhone, every suite
#   DeviceTests/run.sh <udid>               # a specific device
#   DeviceTests/run.sh <udid> KeychainSessionDeviceTests   # one suite
#
# Optional settings, read from your shell (xcodebuild forwards TEST_RUNNER_* to the tests):
#   TEST_RUNNER_SAHHA_APP_ID / TEST_RUNNER_SAHHA_APP_SECRET   sandbox app credentials; without
#                                                             them the live-API suite is skipped
#   TEST_RUNNER_SAHHA_ENVIRONMENT    sandbox (default) or development; production is refused
#   TEST_RUNNER_SAHHA_SEED_DAYS      days of step history to seed (default 365)
#   TEST_RUNNER_SAHHA_SEED_PER_DAY   samples per day (default 288, one every 5 minutes)
#   TEST_RUNNER_SAHHA_KEEP_SEEDED=1  leave the seeded samples in HealthKit after the run
#   TUIST_DEVELOPMENT_TEAM           signing team (default DFT926V374, Sahha Pty Ltd)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
udid="${1:-}"
suite="${2:-}"

if [[ -z "$udid" ]]; then
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null
  udid="$(python3 -c '
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("platform") == "iOS" and conn.get("tunnelState") == "connected":
        print(hw["udid"]); break
' "$json")"
  rm -f "$json"
  [[ -n "$udid" ]] || { echo "No connected iPhone found. Plug one in, unlock it and trust this Mac." >&2; exit 1; }
fi
echo "Device: $udid"

tuist generate --no-open --path "$here" >/dev/null

only=()
[[ -n "$suite" ]] && only=(-only-testing:"SahhaDeviceTests/$suite")

results="$here/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$results"

status=0
xcodebuild test \
  -workspace "$here/SahhaDeviceTests.xcworkspace" \
  -scheme SahhaDeviceTests \
  -destination "id=$udid" \
  -allowProvisioningUpdates \
  -resultBundlePath "$results/SahhaDeviceTests.xcresult" \
  ${only[@]+"${only[@]}"} || status=$?

# The tests write their measurements into the host app's Documents folder.
xcrun devicectl device copy from --device "$udid" \
  --domain-type appDataContainer --domain-identifier ai.sahha.sdk.devicetests \
  --source Documents/device-test-results --destination "$results" >/dev/null 2>&1 \
  && echo "Measurements: $results" \
  || echo "No measurements copied (a suite that records none, or the run stopped early)."

exit "$status"
