# Sahha SDK for iOS Apps

The Sahha SDK provides a convenient way for iOS apps to connect to the Sahha API.

Sahha lets your project seamlessly collect health and lifestyle data from smartphones and wearables via Apple Health, Google Health Connect, and a variety of other sources.

For more information on Sahha please visit https://sahha.ai.

---

## Docs

The Sahha Docs provide detailed instructions for installation and usage of the Sahha SDK.

[Sahha Docs](https://docs.sahha.ai)

---

## Example

The Sahha Demo App provides a convenient way to try the features of the Sahha SDK.

[Sahha Demo App](https://github.com/sahha-ai/sahha-demo-ios)

---

## Health Data Source Integrations

Sahha supports integration with the following health data sources:

- [Apple Health Kit](https://sahha.notion.site/Apple-Health-HealthKit-13cb2f553bbf80c0b117cb662e04c257?pvs=25)
- [Google Fit](https://sahha.notion.site/Google-Fit-131b2f553bbf804a8ee6fef7bc1f4edb?pvs=25)
- [Google Health Connect](https://sahha.notion.site/Health-Connect-Android-13cb2f553bbf806d9d64e79fe9d07d9e?pvs=25)
- [Samsung Health](https://sahha.notion.site/Samsung-Health-d3f76840fad142469f5e724a54c24ead?pvs=25)
- [Garmin Connect](https://sahha.notion.site/Garmin-12db2f553bbf80afb916d04a62e857e6?pvs=25)
- [Polar Flow](https://sahha.notion.site/Polar-12db2f553bbf80c3968eeeab55b484a2?pvs=25)
- [Withings Health Mate](https://sahha.notion.site/Withings-12db2f553bbf80a38d31f80ab083613f?pvs=25)
- [Oura Ring](https://sahha.notion.site/Oura-12db2f553bbf80cf96f2dfd8343b4f06?pvs=25)
- [Whoop](https://sahha.notion.site/WHOOP-12db2f553bbf807192a5c69071e888f4?pvs=25)
- [Strava](https://sahha.notion.site/Strava-12db2f553bbf80c48312c2bf6aa5ac65?pvs=25)

& many more! Please visit our [integrations](https://sahha.notion.site/data-integrations?v=17eb2f553bbf80e0b0b3000c0983ab01) page for more information.

---

## Install

The SDK supports iOS 15 and later, and can be installed with Swift Package Manager or CocoaPods.

#### Swift Package Manager

In Xcode, go to `File > Add Package Dependencies…` and enter the repository URL:

```
https://github.com/sahha-ai/sahha-ios.git
```

Or add it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/sahha-ai/sahha-ios.git", from: "1.3.0")
]
```

#### CocoaPods

In the `Podfile`:

```
platform :ios, '15.0'
target 'YourProjectName' do
  use_frameworks!
  pod 'Sahha' # Use the latest version
end
```

#### Enable HealthKit

- Open your project in Xcode and select your `App Target` in the Project panel.
- Navigate to the `Signing & Capabilities` tab.
- Click the `+` button (or choose `Editor > Add Capability`) to open the Capabilities library.
- Locate and select `HealthKit`; double-click it to add it to your project.

#### Background Delivery

- Select your project in the Project navigator and choose your app’s target.
- In the `Signing & Capabilities` tab, find the HealthKit capability.
- Enable the nested `Background Delivery` option to allow passive health data collection.

#### Add Usage Descriptions

- Select your `App Target` and navigate to the `Info` tab.
- Click the `+` button to add a new key and choose `Privacy - Health Share Usage Description`.
- Provide a clear description, such as: "*This app needs your health info to deliver mood
  predictions*."

For more detailed instructions, refer to
our [setup guide](https://docs.sahha.ai/docs/data-flow/sdk/setup#minimum-requirements).

---

## API

<docgen-index>

* [`configure(...)`](#configure)
* [`isAuthenticated`](#isauthenticated)
* [`authenticate(...)`](#authenticate)
* [`deauthenticate()`](#deauthenticate)
* [`profileToken`](#profiletoken)
* [`getDemographic()`](#getdemographic)
* [`postDemographic(...)`](#postdemographic)
* [`getSensorStatus(...)`](#getsensorstatus)
* [`enableSensors(...)`](#enablesensors)
* [`postSensorData(...)`](#postsensordata)
* [`enableBackgroundRefresh(...)`](#enablebackgroundrefresh)
* [`handleBackgroundSessionEvents(...)`](#handlebackgroundsessionevents)
* [`getScores(...)`](#getscores)
* [`getBiomarkers(...)`](#getbiomarkers)
* [`getStats(...)`](#getstats)
* [`getSamples(...)`](#getsamples)
* [`openAppSettings()`](#openappsettings)
* [Interfaces](#interfaces)
* [Enums](#enums)

</docgen-index>

<docgen-api>

### configure(...)

```swift
public static func configure(_ settings: SahhaSettings, callback: (() -> Void)? = nil)
```

**Example usage**:

```swift
let settings = SahhaSettings(environment: .sandbox)
Sahha.configure(settings)
```

---

### isAuthenticated

```swift
public static var isAuthenticated: Bool
```

**Example usage**:

```swift
if (Sahha.isAuthenticated == false) {
    // E.g. Authenticate the user
}
```

---

### authenticate(...)

```swift
public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.authenticate(
    appId: APP_ID,
    appSecret: APP_SECRET,
    externalId: EXTERNAL_ID // Some unique identifier for the user
) { error, success in
    if let error = error {
        print(error)
    } else if success {
        print(success)
    }
}
```

You can also authenticate directly with a profile token and refresh token:

```swift
public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.authenticate(
    profileToken: PROFILE_TOKEN,
    refreshToken: REFRESH_TOKEN
) { error, success in
    if let error = error {
        print(error)
    } else if success {
        print(success)
    }
}
```

---

### deauthenticate()

```swift
public static func deauthenticate(callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.deauthenticate { error, success in
    if let error = error {
        print(error)
    } else if success {
        print(success)
    }
}
```

---

### profileToken

```swift
public static var profileToken: String?
```

**Example usage**:

```swift
if let profileToken = Sahha.profileToken {
    // Do something with the token
}
```

---

### getDemographic()

```swift
public static func getDemographic(callback: @escaping (String?, SahhaDemographic?) -> Void)
```

**Example usage**:

```swift
Sahha.getDemographic { error, value in
    if let error = error {
        print(error)
    }
    else if let value = value {
        print(value)
    }
}
```

---

### postDemographic(...)

```swift
public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.postDemographic(demographic) { error, success in
    if let error = error {
        print(error)
    }
    print(success)
}
```

---

### getSensorStatus(...)

```swift
public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus)->Void)
```

**Example usage**:

```swift
let sensors: Set<SahhaSensor> = [.steps, .sleep]

Sahha.getSensorStatus(sensors) { error, status in
    if let error = error {
        print(error)
    }
    
    print(status)
}
```

---

### enableSensors(...)

```swift
public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus)->Void)
```

**Example usage**:

```swift
let sensors: Set<SahhaSensor> = [.steps, .sleep]

Sahha.enableSensors(sensors) { error, status in
    if let error = error {
        print(error)
    } 
    
    print(status)
}
```

You may also pass an umbrella sensor (`.nutrition`, `.reproductive`, or `.symptom`) to request
permission for every granular sensor in that category at once:

```swift
let sensors: Set<SahhaSensor> = [.nutrition, .reproductive]

Sahha.enableSensors(sensors) { error, status in
    print(status)
}
```

---

### postSensorData(...)

Manually triggers a query and upload of the latest sensor data. The SDK collects data passively in
the background, so calling this is optional.

```swift
public static func postSensorData(debug: Bool = false, callback: (@Sendable (PostSensorDataResult) -> Void)? = nil)
```

**Example usage**:

```swift
Sahha.postSensorData { result in
    print("Sensors queried: \(result.totalSensors)")
    print("Samples fetched: \(result.totalSamples)")
    print("Logs produced: \(result.totalLogs)")
}
```

---

### enableBackgroundRefresh(...)

Enables automatic background refresh for reliable passive data collection. Registers the task and
automatically schedules refreshes when the app enters the background. Call this in
`application(_:didFinishLaunchingWithOptions:)`. The identifier must match a `BGTaskSchedulerPermittedIdentifiers`
entry in your `Info.plist`.

```swift
public static func enableBackgroundRefresh(identifier: String)
```

**Example usage**:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Sahha.enableBackgroundRefresh(identifier: "ai.sahha.background.refresh")
    return true
}
```

---

### handleBackgroundSessionEvents(...)

Handles background `URLSession` completion events. Call this from your AppDelegate's
`application(_:handleEventsForBackgroundURLSession:completionHandler:)`.

```swift
public static func handleBackgroundSessionEvents(identifier: String, completionHandler: @escaping @Sendable () -> Void)
```

**Example usage**:

```swift
func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
    Sahha.handleBackgroundSessionEvents(identifier: identifier, completionHandler: completionHandler)
}
```

---

### getScores(...)

```swift
public static func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, String?) -> Void)
```

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

let types: Set<SahhaScoreType> = [.activity]

Sahha.getScores(types: types, startDateTime: sevenDaysAgo, endDateTime: today) { error, json in
    if let error = error {
        print(error)
    } else if let json = json {
        print(json)
    }
}
```

---

### getBiomarkers(...)

```swift
public static func getBiomarkers(
    categories: Set<SahhaBiomarkerCategory>,
    types: Set<SahhaBiomarkerType>,
    startDateTime: Date,
    endDateTime: Date,
    callback: @escaping (String?, String?) -> Void
)
```

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

let categories: Set<SahhaBiomarkerCategory> = [.activity, .sleep, .vitals]
let types: Set<SahhaBiomarkerType> = [.steps, .sleep_duration, .heart_rate_sleep, .heart_rate_resting]

Sahha.getBiomarkers(
    categories: categories,
    types: types,
    startDateTime: sevenDaysAgo, endDateTime: today
) { error, json in
    if let error = error {
        print(error)
    } else if let json = json {
        print(json)
    }
}
```

---

### getStats(...)

> **Deprecated**: Use [getBiomarkers(...)](#getbiomarkers) instead — server-processed biomarkers are the supported read API.

```swift
public static func getStats(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaStat])->Void)
```

> **Note**: `SahhaStat.category` contains the sensor's data log type — the same label the SDK stamps on the data it uploads (e.g. `sleep`, `activity`, `energy`, `heart`, `blood`, `oxygen`, `temperature`, `body`, `exercise`, `nutrition`). This vocabulary is intentionally different from the six `SahhaBiomarkerCategory` values used by `getBiomarkers(...)`.

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

Sahha.getStats(sensor: .steps, startDateTime: sevenDaysAgo, endDateTime: today) { error, newStats in
    if let error = error {
        print(error)
    }
    
    print(newStats)
}
```

---

### getSamples(...)

> **Deprecated**: Use [getBiomarkers(...)](#getbiomarkers) instead — server-processed biomarkers are the supported read API.

```swift
public static func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaSample])->Void)
```

> **Note**: `SahhaSample.category` is labeled the same way as `SahhaStat.category` — see [getStats](#getstats) above.

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

Sahha.getSamples(sensor: .steps, startDateTime: sevenDaysAgo, endDateTime: today) { error, newSamples in
    if let error = error {
        print(error)
    }
    
    print(newSamples)
}
```

---

### openAppSettings()

```swift
public static func openAppSettings()
```

**Example usage**:

```swift
// This method is useful when the user denies permissions multiple times -- where the prompt will no longer show
if status == SahhaSensorStatus.disabled {
    Sahha.openAppSettings()
}
```

---

### Interfaces

#### SahhaSettings

```swift
public struct SahhaSettings {
    public let environment: SahhaEnvironment /// sandbox or production
    public var framework: SahhaFramework = .ios_swift /// automatically set by sdk
    /// When enabled, uses CoreMotion pedometer to trigger background data collection
    /// and provide fallback step data when HealthKit is unavailable.
    /// Requires `NSMotionUsageDescription` in Info.plist. Default: false
    public var enableMotionTrigger: Bool = false
}
```

#### SahhaDemographic

```swift
public struct SahhaDemographic: Codable, Equatable {
    public var gender: String?
    public var birthDate: String?
}
```

#### SahhaStat

```swift
public struct SahhaStat: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var aggregation: String
    public var periodicity: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var sources: [String]
}
```

#### SahhaSample

```swift
public struct SahhaSample: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var recordingMethod: String
    public var source: String
    public var stats: [SahhaStat]
}
```

### Enums

#### SahhaEnvironment

```swift
public enum SahhaEnvironment: String {
    case sandbox
    case production
}
```

#### SahhaSensor

```swift
public enum SahhaSensor: String, CaseIterable {
    // Activity
    case activity_summary
    case active_energy_burned
    case exercise
    case exercise_time
    case floors_climbed
    case move_time
    case running_ground_contact_time
    case running_power
    case running_speed
    case running_stride_length
    case running_vertical_oscillation
    case six_minute_walk_test_distance
    case stair_ascent_speed
    case stair_descent_speed
    case stand_time
    case steps
    case time_in_daylight
    case walking_asymmetry_percentage
    case walking_double_support_percentage
    case walking_speed
    case walking_steadiness
    case walking_step_length

    // Blood
    case blood_glucose
    case blood_pressure_diastolic
    case blood_pressure_systolic

    // Body
    case body_fat
    case body_mass_index
    case body_water_mass
    case bone_mass
    case height
    case lean_body_mass
    case waist_circumference
    case weight

    // Demographic
    case date_of_birth
    case gender

    // Device
    case device_lock

    // Energy
    case basal_energy_burned
    case basal_metabolic_rate
    case total_energy_burned

    // Heart
    case heart_rate
    case heart_rate_variability_rmssd
    case heart_rate_variability_sdnn
    case resting_heart_rate
    case walking_heart_rate_average

    // Oxygen
    case oxygen_saturation
    case respiratory_rate
    case vo2_max

    // Sleep
    case sleep

    // Temperature
    case basal_body_temperature
    case body_temperature
    case sleeping_wrist_temperature

    // Nutrition
    case energy_intake
    case protein_intake
    case fat_intake
    case fat_saturated_intake
    case fat_monounsaturated_intake
    case fat_polyunsaturated_intake
    case cholesterol_intake
    case carbohydrate_intake
    case sugar_intake
    case fiber_intake
    case vitamin_a_intake
    case vitamin_d_intake
    case vitamin_e_intake
    case vitamin_k_intake
    case vitamin_c_intake
    case vitamin_b6_intake
    case vitamin_b12_intake
    case thiamin_intake
    case riboflavin_intake
    case niacin_intake
    case pantothenic_acid_intake
    case folate_intake
    case biotin_intake
    case calcium_intake
    case iron_intake
    case magnesium_intake
    case phosphorus_intake
    case potassium_intake
    case sodium_intake
    case zinc_intake
    case chloride_intake
    case copper_intake
    case manganese_intake
    case chromium_intake
    case molybdenum_intake
    case selenium_intake
    case iodine_intake
    case caffeine_intake
    case water_intake

    // Reproductive Health - Menstrual Cycle
    case menstrual_flow
    case intermenstrual_bleeding
    case infrequent_menstrual_cycles
    case irregular_menstrual_cycles
    case persistent_intermenstrual_bleeding
    case prolonged_menstrual_periods
    case menstrual_period // Android-only (no HealthKit equivalent)

    // Reproductive Health - Fertility
    case ovulation_test
    case cervical_mucus

    // Reproductive Health - Sexual Activity
    case sexual_activity
    case contraceptive

    // Reproductive Health - Pregnancy
    case pregnancy
    case pregnancy_test
    case progesterone_test
    case lactation

    // Symptoms
    case abdominal_cramps
    case acne
    case appetite_changes
    case bladder_incontinence
    case bloating
    case breast_pain
    case chest_tightness_or_pain
    case chills
    case constipation
    case coughing
    case diarrhea
    case dizziness
    case dry_skin
    case fainting
    case fatigue
    case fever
    case generalized_body_ache
    case hair_loss
    case headache
    case heartburn
    case hot_flashes
    case loss_of_smell
    case loss_of_taste
    case lower_back_pain
    case memory_lapse
    case mood_changes
    case nausea
    case night_sweats
    case pelvic_pain
    case rapid_pounding_or_fluttering_heartbeat
    case runny_nose
    case shortness_of_breath
    case sinus_congestion
    case skipped_heartbeat
    case sleep_changes
    case sore_throat
    case vaginal_dryness
    case vomiting
    case wheezing

    // Umbrella sensors -- request permission for every granular sensor in the
    // category at once. Expanded internally to the underlying sensors.
    case nutrition    // All dietary/nutrition types
    case reproductive // All reproductive health types
    case symptom      // All symptom types
}
```

#### SahhaSensorStatus

```swift
public enum SahhaSensorStatus: String {
    case pending /// Sensor data is pending User permission
    case unavailable /// Sensor data is not supported by the User's device
    case disabled /// Sensor data has been disabled by the User
    case enabled /// Sensor data has been enabled by the User
    case indeterminate /// Sensor may be denied or simply has no data yet
}
```

#### SahhaScoreType

```swift
public enum SahhaScoreType: String {
    case wellbeing
    case activity
    case sleep
    case readiness
    case mental_wellbeing
}
```

#### SahhaBiomarkerCategory

```swift
public enum SahhaBiomarkerCategory: String {
    case activity
    case body
    case engagement
    case nutrition
    case sleep
    case vitals
}
```

#### SahhaBiomarkerType

```swift
public enum SahhaBiomarkerType: String {
    case steps
    case floors_climbed
    case active_hours
    case active_duration
    case activity_low_intensity_duration
    case activity_medium_intensity_duration
    case activity_high_intensity_duration
    case activity_sedentary_duration
    case active_energy_burned
    case total_energy_burned
    case height
    case weight
    case body_mass_index
    case body_fat
    case fat_mass
    case lean_mass
    case waist_circumference
    case resting_energy_burned
    case age
    case biological_sex
    case date_of_birth
    case menstrual_cycle_length
    case menstrual_cycle_start_date
    case menstrual_cycle_end_date
    case menstrual_phase
    case menstrual_phase_start_date
    case menstrual_phase_end_date
    case menstrual_phase_length
    case sleep_start_time
    case sleep_end_time
    case sleep_duration
    case sleep_debt
    case sleep_interruptions
    case sleep_in_bed_duration
    case sleep_awake_duration
    case sleep_light_duration
    case sleep_rem_duration
    case sleep_deep_duration
    case sleep_regularity
    case sleep_latency
    case sleep_efficiency
    case heart_rate_resting
    case heart_rate_sleep
    case heart_rate_variability_sdnn
    case heart_rate_variability_rmssd
    case respiratory_rate
    case respiratory_rate_sleep
    case oxygen_saturation
    case oxygen_saturation_sleep
    case vo2_max
    case blood_glucose
    case blood_pressure_systolic
    case blood_pressure_diastolic
    case body_temperature_basal
    case skin_temperature_sleep
}
```


</docgen-api>

---

Copyright © 2022 Sahha. All rights reserved.
