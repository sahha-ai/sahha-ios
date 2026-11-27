#!/usr/bin/env bash
# The background-wake check (MANUAL_CHECKLIST.md, item 1) on a connected iPhone, with the
# Wake Check app: a minimal host app built from this checkout's SDK.
#
#   DeviceTests/wake-check.sh install [udid]   build and install Wake Check, then launch it
#                                              once with the app credentials so it signs in
#                                              to its own profile, sahha-ios-wake-check
#   DeviceTests/wake-check.sh log [udid]       copy its timeline back to DeviceTests/results/
#                                              and show what happened since it last left
#                                              the foreground
#
# Settings come from DeviceTests/.env.local, as for run.sh: TEST_RUNNER_SAHHA_ENVIRONMENT
# (sandbox by default; production is refused), TEST_RUNNER_SAHHA_APP_ID and
# TEST_RUNNER_SAHHA_APP_SECRET. The credentials reach the app as environment variables of
# that one launch, never on a command line, and the app's log redacts them.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bundle_id="ai.sahha.sdk.wakecheck"

usage() { sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//'; }

command="${1:-}"
udid="${2:-}"
[[ "$command" == "install" || "$command" == "log" ]] || { usage >&2; exit 2; }

if [[ -f "$here/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$here/.env.local"
  set +a
fi

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

if [[ "$command" == "install" ]]; then
  environment="${TEST_RUNNER_SAHHA_ENVIRONMENT:-sandbox}"
  [[ "$environment" != "production" ]] || { echo "Refusing to run against production." >&2; exit 1; }
  : "${TEST_RUNNER_SAHHA_APP_ID:?Set TEST_RUNNER_SAHHA_APP_ID in DeviceTests/.env.local}"
  : "${TEST_RUNNER_SAHHA_APP_SECRET:?Set TEST_RUNNER_SAHHA_APP_SECRET in DeviceTests/.env.local}"

  tuist generate --no-open --path "$here" >/dev/null
  echo "Building Wake Check…"
  xcodebuild build \
    -workspace "$here/SahhaDeviceTests.xcworkspace" \
    -scheme SahhaWakeCheck \
    -configuration Debug \
    -destination "id=$udid" \
    -derivedDataPath "$here/build" \
    -allowProvisioningUpdates \
    -quiet
  xcrun devicectl device install app --device "$udid" \
    "$here/build/Build/Products/Debug-iphoneos/SahhaWakeCheck.app" >/dev/null

  # devicectl passes DEVICECTL_CHILD_* variables to the app without the prefix.
  DEVICECTL_CHILD_SAHHA_ENVIRONMENT="$environment" \
  DEVICECTL_CHILD_SAHHA_APP_ID="$TEST_RUNNER_SAHHA_APP_ID" \
  DEVICECTL_CHILD_SAHHA_APP_SECRET="$TEST_RUNNER_SAHHA_APP_SECRET" \
    xcrun devicectl device process launch --device "$udid" --terminate-existing "$bundle_id" >/dev/null

  cat <<EOF
Installed and launched Wake Check ($environment). On the phone:
  1. Check "Signed in" says yes, then tap "Enable steps and heart rate" and allow both.
  2. Wait for "Successfully uploaded chunk" in the app's events: the first sync is done.
  3. Follow MANUAL_CHECKLIST.md item 1, then run: DeviceTests/wake-check.sh log
EOF
  exit 0
fi

results="$here/results/wake-check-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$results"
log="$results/wake-check.log"
# A single file's destination is the file itself, not a folder.
xcrun devicectl device copy from --device "$udid" \
  --domain-type appDataContainer --domain-identifier "$bundle_id" \
  --source Documents/wake-check.log --destination "$log" >/dev/null \
  || { echo "Couldn't copy the log. Is Wake Check installed (wake-check.sh install) and the phone unlocked?" >&2; exit 1; }
[[ -f "$log" ]] || { echo "The copy produced no $log" >&2; exit 1; }

python3 - "$log" <<'PY'
import re, sys
from datetime import datetime, timedelta

def parse(line):
    try:
        return datetime.strptime(line[:23], "%Y-%m-%d %H:%M:%S.%f"), line[24:].rstrip("\n")
    except ValueError:
        return None, None

events = [e for e in (parse(l) for l in open(sys.argv[1], encoding="utf-8", errors="replace")) if e[0]]

KEY = re.compile(
    r"\[WakeCheck\]|Background delivery triggered|Background observer query completed"
    r"|Background query error|Successfully uploaded chunk|\[Background Upload\]"
    r"|Background refresh task|Stored batch|Upload failed|\[Sahha Error\]|Session expired"
)
DELIVERY = "Background delivery triggered for "
# Logged after the query a delivery triggers: its status and how many logs it produced.
QUERY = re.compile(r"Background observer query completed for (\w+): (\w+), samples: (\d+), logs: (\d+)")
# The uploader sends one priority per chunk: steps go as critical, other HealthKit data
# as high, and device logs (one at every launch, among others) as normal. Only the first
# two are evidence that health data went up.
UPLOADED = re.compile(r"Successfully uploaded chunk with (\d+) items \(priority: (\w+)\)")
HEALTH_PRIORITIES = {"critical", "high"}
# "Stored batch … while offline" isn't counted: at launch the network monitor hasn't
# reported yet, and the batch goes up a second later. It's still listed above.
ERROR = re.compile(r"\[Sahha Error\]|Background query error|Upload failed|sign-in failed|Session expired")

def show(rows, note=lambda i: ""):
    for i, (t, m) in rows:
        print(f"  {t:%H:%M:%S} {m[:160]}{note(i)}")

left = [i for i, (_, m) in enumerate(events)
        if "[WakeCheck] left the foreground" in m or "[WakeCheck] quitting" in m]
if not left:
    print("The app hasn't left the foreground yet. Latest events:")
    show([(i, e) for i, e in enumerate(events) if KEY.search(e[1])][-25:])
    sys.exit(0)

start = left[-1]
quit_ = "quitting" in events[start][1]
window = events[start:]
reopen = next((i for i, (_, m) in enumerate(window) if "[WakeCheck] opened" in m), None)
before = window[:reopen] if reopen is not None else window
reopened_at = window[reopen][0] if reopen is not None else None

key_rows = [(i, e) for i, e in enumerate(window) if KEY.search(e[1])]
print(f"Since the app {'quit' if quit_ else 'left the foreground'} at {window[0][0]:%Y-%m-%d %H:%M:%S}:")
show(key_rows[-60:], lambda i: "   (after reopening)" if reopen is not None and i > reopen else "")

# A launch just before "opened" is the user opening the app, not iOS waking it.
launches = [t for t, m in before if "[WakeCheck] launch" in m
            and not (reopened_at and reopened_at - t < timedelta(seconds=5))]
deliveries = [m.split(DELIVERY, 1)[1] for _, m in before if DELIVERY in m]
queries = [(t, q.group(1), q.group(2), int(q.group(4))) for t, m in before if (q := QUERY.search(m))]
# Queries that collected new health data, and the health uploads after the first of them.
collected = [(t, sensor, logs) for t, sensor, status, logs in queries if status == "success" and logs > 0]
first_collected = collected[0][0] if collected else None
health_uploaded = sum(
    int(u.group(1)) for t, m in before
    if first_collected and t >= first_collected
    and (u := UPLOADED.search(m)) and u.group(2) in HEALTH_PRIORITIES
)
device_uploads = sum(1 for _, m in before if (u := UPLOADED.search(m)) and u.group(2) not in HEALTH_PRIORITIES)
logs_collected = sum(logs for _, _, logs in collected)
errors = [m for _, m in before if ERROR.search(m)]

by_sensor = {}
for _, sensor, logs in collected:
    by_sensor[sensor] = by_sensor.get(sensor, 0) + logs
results = sorted({f"{sensor} {status}" + (f" {logs} logs" if logs else "") for _, sensor, status, logs in queries})

print()
print(f"Before {'reopening at ' + f'{reopened_at:%H:%M:%S}' if reopened_at else 'now (not reopened yet)'}:")
print(f"  background launches by iOS: {len(launches)}")
print(f"  HealthKit deliveries: {len(deliveries)}" + (f" ({', '.join(sorted(set(deliveries)))})" if deliveries else ""))
print(f"  query results: {', '.join(results) if results else 'none'}")
print(f"  new health logs collected: {logs_collected}"
      + (f" ({', '.join(f'{s} {n}' for s, n in sorted(by_sensor.items()))})" if by_sensor else ""))
print(f"  health items uploaded after that: {health_uploaded}"
      + (f" (device-log uploads, not counted: {device_uploads})" if device_uploads else ""))
print(f"  errors: {len(errors)}")
if logs_collected and health_uploaded >= logs_collected and (launches or not quit_):
    print("PASS: iOS woke the app, a query collected the new health data, and the SDK uploaded it "
          "before the app was reopened.")
elif logs_collected and health_uploaded:
    print(f"NOT YET: {logs_collected} new health logs were collected but only {health_uploaded} items uploaded. "
          "Check the errors above.")
elif logs_collected:
    print(f"NOT YET: {logs_collected} new health logs were collected, but none were uploaded. Check the errors above.")
elif deliveries:
    print("NOT YET: iOS delivered updates, but no query collected new health data. See the query results.")
elif quit_ and launches:
    print("NOT YET: iOS launched the app, but no HealthKit delivery arrived.")
else:
    print("NOT YET: iOS hasn't woken the app for new data. Step deliveries can take up to an hour.")
PY
echo "Full log: $log"
