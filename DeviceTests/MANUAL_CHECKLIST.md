# Manual device checklist

For what XCTest can't drive: the lock screen, suspension, background delivery and
upgrades.

Checks 1 and 2 use **Wake Check** (`DeviceTests/WakeCheck`), a minimal host app built from
this checkout's SDK. It starts the SDK at every launch the way a customer's app does, and
keeps a timeline of its launches, the SDK's debug log (HealthKit deliveries, uploads,
errors) and when it was opened, with the credentials redacted. `DeviceTests/wake-check.sh`
installs it and reads the timeline back. It signs in to its own profile,
`sahha-ios-wake-check`, in the environment set in `DeviceTests/.env.local`.

The other checks need a host app that integrates the SDK build under test (the Flutter
demo app, or any test app), signed in to a **sandbox** profile. There the SDK's console
logging (`Sahha.debugLogging`) is internal and off, so judge by what reaches the profile
(its data logs in the dashboard or the API), by `Sahha.isAuthenticated`, and by the SDK
error log in the log store.

Record each run: SDK version or commit, device, iOS version, date, and pass or fail with
the evidence.

## 1. Background delivery after suspension

Run it twice, once for each way of leaving the app in step 3.

1. Run `DeviceTests/wake-check.sh install`. It builds and installs Wake Check, then launches it
   once with the credentials so it signs in.
2. On the phone, tap **Enable steps and heart rate** and allow both. Wait for "Successfully
   uploaded chunk" in the app's events: the first sync is done.
3. Leave the app:
   - **Suspended:** go to the home screen.
   - **Not running:** tap **Quit, as iOS would**. Don't swipe it away in the app switcher
     instead: iOS doesn't launch an app in the background after the user force-quits it.
4. In the Health app, add a heart rate reading and some steps (Browse → Heart → Heart Rate →
   Add Data, and the same for Steps), or walk about 200 steps. Lock the phone.
5. Wait without opening Wake Check. On iOS 27.2.1, entries added by hand arrived within
   seconds. Apple documents some types, steps among them, as delivered at most hourly, so
   allow up to an hour before calling it a fail.
6. Unlock the phone, still without opening Wake Check, and run `DeviceTests/wake-check.sh log`.
   It saves the timeline to `DeviceTests/results/` and sums up what happened since the app
   left the foreground. Run it as often as you like.
7. **Pass:** the summary says PASS: a HealthKit delivery and an upload after the app left
   the foreground and before it was reopened, and, when it wasn't running, a launch by iOS.

## 2. Background launch before first unlock

Wake Check's timeline is written even before the first unlock, so it shows any launch iOS
makes then.

1. Authenticate, then restart the phone and **don't unlock it**.
2. Walk, or wait for a scheduled background refresh, so iOS launches the app in the background.
3. Unlock the phone and open the app.
4. **Pass:** `Sahha.isAuthenticated` is true, no "Session expired" error was logged, and data
   uploads within a few minutes of unlocking.

## 3. Upgrade from an older release

Run once from each release customers are still on (at least 1.3.7 and 1.4.0).

1. Install a host app built with the old release, authenticate, enable sensors and sync.
2. Install the same app built with the SDK under test over it, without deleting it.
3. **Pass:** still authenticated, `getSensors()` returns the enabled sensors (see the 1.3.9
   sensor-store poisoning), no full re-sync of 30 days for sensors that already had anchors,
   and new data uploads.

## 4. Token refresh after a long idle

1. Authenticate with a profile token close to expiry: a token from `POST /oauth/profile/token`
   (account token required) with `lifetime` of 2100 seconds (35 minutes).
2. Background the app for an hour.
3. Bring it to the foreground.
4. **Pass:** uploads succeed and `Sahha.isAuthenticated` stays true. With the API's
   refresh-failure logging deployed, no "Profile token refresh failed" row appears for the profile.

## 5. Health permission sheet

1. Fresh install, call `enableSensors` with every sensor the host app uses.
2. **Pass:** every requested type appears on the sheet. Blood pressure missing on iOS 26.5.x is
   Apple's bug (fixed in 26.6), not the SDK.
