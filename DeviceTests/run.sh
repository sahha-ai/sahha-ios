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
#
# Any of these can also live in DeviceTests/.env.local (git-ignored), one NAME=value per
# line, which this script loads first. Keep app credentials there rather than in your
# shell history.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "$here/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$here/.env.local"
  set +a
fi
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

run_id="$(date +%Y%m%d-%H%M%S)"
results="$here/results/$run_id"
mkdir -p "$results"
# The tests write this run's reports to their own folder on the phone, and remove
# earlier runs' reports, so only this run's measurements come back.
export TEST_RUNNER_SAHHA_RUN_ID="$run_id"

status=0
# One suite at a time, whatever the scheme or a test plan says: the suites share the
# app's HealthKit store, keychain and live profile (see the scheme in Project.swift).
xcodebuild test \
  -workspace "$here/SahhaDeviceTests.xcworkspace" \
  -scheme SahhaDeviceTests \
  -destination "id=$udid" \
  -parallel-testing-enabled NO \
  -allowProvisioningUpdates \
  -resultBundlePath "$results/SahhaDeviceTests.xcresult" \
  ${only[@]+"${only[@]}"} || status=$?

# Only this run's folder: a run that recorded nothing finds none and copies nothing.
xcrun devicectl device copy from --device "$udid" \
  --domain-type appDataContainer --domain-identifier ai.sahha.sdk.devicetests \
  --source "Documents/device-test-results/$run_id" --destination "$results" >/dev/null 2>&1 \
  && echo "Measurements: $results" \
  || echo "No measurements from this run (its suites record none, or it stopped before recording)."

exit "$status"
