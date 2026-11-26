# Device regression tests

Tests that only a real iPhone can answer: real HealthKit with a large history, the
device keychain, and the live API on a phone's network. The simulator suite in
`Tests/SahhaTests` stays the fast, everyday check; this one runs before a release, or
when a change touches HealthKit queries, the keychain or token refresh.

## Run it

```bash
DeviceTests/run.sh
```

That generates the Xcode project with Tuist, builds, signs, installs and runs every suite
on the first connected iPhone, then copies each test's measurements into
`DeviceTests/results/<timestamp>/`. Pass a UDID and a suite name to narrow it:
`DeviceTests/run.sh <udid> FirstSyncDeviceTests`.

Needs: Tuist (`brew install tuist`), Xcode signed in to an account in the Sahha team, and
a phone with Developer Mode on, unlocked and trusted. The first signed build registers
the `ai.sahha.sdk.devicetests` app id with HealthKit.

**First run only:** the Health permission sheet appears on the phone. Tap
**Turn On All**, then **Allow**. The answer sticks for this app on that phone.

The live-API suite runs only with sandbox credentials in your shell:

```bash
export TEST_RUNNER_SAHHA_APP_ID=…
export TEST_RUNNER_SAHHA_APP_SECRET=…
```

Every setting is listed at the top of `run.sh`.

## What it covers

| Suite | Checks | Why a device |
|---|---|---|
| `FirstSyncDeviceTests` | A first sync pages through the 30-day window under a large step history without a page timing out (and under half the budget); records page times, and the first page without a date predicate for comparison | The first page scans every older sample, so its cost depends on the phone and the history. 1.4.0 field report; PR #108 |
| `KeychainSessionDeviceTests` | The session survives a fresh store, is readable by `isAuthenticated`, is stored as readable after first unlock, and clears | The simulator keychain has no data protection |
| `TokenRefreshDeviceTests` | A real refresh through the SDK's AuthManager, the new token authorising a request, a chained refresh, and a 400 keeping the session | The live API from the phone's network, not mocks |
| `SeedCleanupDeviceTests` | Deletes every sample this app wrote and confirms none remain. Runs only with `TEST_RUNNER_SAHHA_CLEANUP=1` | Recovery after a stopped run |

## History size and run time

The default seed is one year at one sample every five minutes (105,120 samples): about
15 seconds to seed and a minute to delete on an iPhone 14. Heavier histories are set with
`TEST_RUNNER_SAHHA_SEED_DAYS` and `TEST_RUNNER_SAHHA_SEED_PER_DAY`. Five years at Apple
Watch density (1825 days × 960 = 1.75M samples) takes about 5 minutes to seed and
12 minutes to delete, so set it only on purpose.

Deletes always go a month at a time. A single HealthKit delete of 1.75M samples ran for
over two hours without finishing, blocked every other HealthKit request from the app,
and was only undone by restarting the phone, which rolled it back.

To measure a **cold** first page, which the simulator found up to 70 times slower than a
warm one, keep a seed and measure it after a reboot:

```bash
TEST_RUNNER_SAHHA_KEEP_SEEDED=1 DeviceTests/run.sh <udid> FirstSyncDeviceTests
# restart the phone and unlock it, then:
TEST_RUNNER_SAHHA_REUSE_SEEDED=1 DeviceTests/run.sh <udid> FirstSyncDeviceTests
```

The second run measures the samples already on the phone, without reseeding, and deletes
them at the end.

## Your phone's own data

The first-sync suite writes step samples dated a day before the 30-day window and
deletes them when it finishes, a month at a time. The SDK ignores samples that old, so
other Sahha apps on the phone don't upload them. Counts and deletes only ever match
samples this app wrote; nothing from another source is touched. If a run stops before
its clean-up, the next first-sync run deletes the leftovers first, or run the clean-up on
its own:

```bash
TEST_RUNNER_SAHHA_CLEANUP=1 DeviceTests/run.sh <udid> SeedCleanupDeviceTests
```

## What can't be automated

XCTest can't lock the phone, suspend the app, wait for iOS to deliver background updates,
or install an older SDK release. Those checks are in [MANUAL_CHECKLIST.md](MANUAL_CHECKLIST.md).
