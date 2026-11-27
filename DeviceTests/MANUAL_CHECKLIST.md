# Manual device checklist

For what XCTest can't drive: the lock screen, suspension, background delivery and
upgrades. Use a host app that integrates the SDK build under test (the Flutter demo app,
or any test app), signed in to a **sandbox** profile.

The SDK's own console logging (`Sahha.debugLogging`) is internal and off, so a host app
can't show it. Judge each check by what reaches the sandbox profile (its data logs in the
dashboard or the API), by `Sahha.isAuthenticated`, and by the SDK error log in the log
store.

Record each run: SDK version or commit, device, iOS version, date, and pass or fail with
the evidence.

## 1. Background delivery after suspension

1. Authenticate, enable steps, and let the first sync finish in the foreground.
2. Background the app, lock the phone, and walk about 200 steps (or add steps in the Health app).
3. Wait 10 minutes without opening the app.
4. **Pass:** the sandbox profile shows the new steps, uploaded before you reopened the app.

## 2. Background launch before first unlock

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
