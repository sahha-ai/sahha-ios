# Sahha iOS SDK - Architecture Diagrams

## 1. OVERALL SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PUBLIC API LAYER                                  │
│                         (Sahha.swift)                                       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  Static Methods:                                                       │ │
│  │  • configure(settings, callback)                                      │ │
│  │  • authenticate(appId, appSecret, externalId, callback)               │ │
│  │  • getDemographic(callback)                                           │ │
│  │  • enableSensors(sensors, callback)                                    │ │
│  │  • postSensorData(debug, callback)                                     │ │
│  │  • getScores(types, dates, callback)                                    │ │
│  │  • getBiomarkers(categories, types, dates, callback)                   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                               │
│                              ▼                                               │
└──────────────────────────────┼───────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER                                      │
│                    (SahhaActor.swift)                                        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  Actor SahhaActor {                                                   │  │
│  │    • configure(with: settings) → DIContainer setup                   │  │
│  │    • startAuthenticatedServices() → Parallel startup                  │  │
│  │    • authManager() → Resolve from DI                                 │  │
│  │    • healthKitManager() → Resolve from DI                            │  │
│  │    • scoreManager() → Resolve from DI                                │  │
│  │    • demographicManager() → Resolve from DI                         │  │
│  │  }                                                                    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                              │                                               │
│                              ▼                                               │
└──────────────────────────────┼───────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEPENDENCY INJECTION LAYER                                │
│                    (DIContainer.swift)                                       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  actor DIContainer {                                                 │  │
│  │    factories: [ObjectIdentifier: Factory]                            │  │
│  │    instances: [ObjectIdentifier: Sendable]  (singletons)             │  │
│  │                                                                      │  │
│  │    register<T>(type, factory) → Store factory                        │  │
│  │    resolve<T>(type) → Create/return singleton                       │  │
│  │    reset() → Dispose all, clear factories                            │  │
│  │  }                                                                    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                              │                                               │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  DI Registration Modules (called by SahhaActor.configure):          │  │
│  │                                                                      │  │
│  │  • StorageDI → KeychainStorage, UserDefaultsStorage                 │  │
│  │  • DeviceInfoDI → DeviceInfoBuilder, DeviceIdProvider               │  │
│  │  • NetworkingDI → APIClient, CircuitBreaker, NetworkMonitor         │  │
│  │  • LoggingDI → ErrorLogger, ErrorLoggingService                     │  │
│  │  • AuthDI → AuthManager, AuthService, TokenStore                   │  │
│  │  • DataLogDI → DataLogUploader, DeadLetterQueue, Pipeline           │  │
│  │  • HealthKitDI → HealthKitManager, Observers, Coordinators           │  │
│  │  • ScoreDI → ScoreManager, ScoreService                            │  │
│  │  • BiomarkerDI → BiomarkerManager, BiomarkerService                 │  │
│  │  • DemographicDI → DemographicManager, DemographicService           │  │
│  │  • DeviceInfoSyncDI → DeviceInfoSyncManager, Service                │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2. CORE COMPONENTS RELATIONSHIPS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CORE LAYER                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  DIContainer     │◄─────┤  SahhaActor      │──────┤  LifecycleObserver│
│  (DI Hub)        │      │  (Orchestrator)  │      │  (Event Manager)  │
└────────┬─────────┘      └────────┬──────────┘      └────────┬──────────┘
         │                        │                           │
         │                        │                           │
         ▼                        ▼                           ▼
    ┌─────────┐            ┌──────────────┐            ┌──────────────┐
    │Factory  │            │Resolve       │            │Register      │
    │Registry │            │Managers      │            │Listeners     │
    └─────────┘            └──────────────┘            └──────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         NETWORKING LAYER                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  APIClient       │◄─────┤  CircuitBreaker   │◄─────┤  NetworkMonitor  │
│                  │      │                  │      │                  │
│  • send()        │      │  • shouldAllow()  │      │  • isConnected   │
│  • compressGzip()│      │  • recordSuccess()│      │  • waitFor()     │
│  • buildRequest()│      │  • recordFailure()│      │  • onStateChange│
└────────┬─────────┘      └────────┬──────────┘      └────────┬──────────┘
         │                        │                           │
         │                        │                           │
         ▼                        ▼                           ▼
    ┌─────────┐            ┌──────────────┐            ┌──────────────┐
    │URLSession│           │State Machine │            │NWPathMonitor │
    │(HTTP)    │           │(open/closed) │            │(System API)  │
    └─────────┘            └──────────────┘            └──────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         STORAGE LAYER                                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  KeychainStorage │      │UserDefaultsStorage│      │DeadLetterQueue   │
│                  │      │                  │      │                  │
│  • saveToken()   │      │  • save()         │      │  • persistBatch()│
│  • token()       │      │  • get()          │      │  • loadAllBatches│
│  • clear()       │      │  • remove()       │      │  • removeBatch() │
└──────────────────┘      └──────────────────┘      └────────┬──────────┘
                                                               │
                                                               ▼
                                                          ┌─────────┐
                                                          │FileSystem│
                                                          │(JSON)    │
                                                          └─────────┘
```

## 3. DATA FLOW: HealthKit → DataLogs → Upload

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HEALTHKIT DATA COLLECTION FLOW                            │
└─────────────────────────────────────────────────────────────────────────────┘

    [HealthKit Framework]
           │
           │ HKObserverQuery fires on data change
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  HealthKitObserverService                                                   │
│  • startObservers(for: sensors, handler)                                    │
│  • HKObserverQuery.updateHandler → checks CircuitBreaker                    │
│  • If healthy → calls handler(sensor, sampleType)                          │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ handler(sensor, sampleType)
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  HealthKitDataLogCoordinator                                                │
│  • launchTrackedQuery(for: sensor, sampleType)                             │
│  • runSensorQuery() → checks CircuitBreaker again                          │
│  • anchorQueryService.runAnchorQuery() → fetches samples                   │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ samples: [HKSample]
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  HKSampleToDataLogNormaliserRegistry                                        │
│  • normalise(sample) → [DataLog]                                            │
│  • Uses specific normalisers:                                               │
│    - HKHeartRateToDataLogNormaliser                                         │
│    - HKBloodGlucoseToDataLogNormaliser                                      │
│    - HKSleepAnalysisToDataLogNormaliser                                     │
│    - HKWorkoutToDataLogNormaliser                                           │
│    - FallbackHKSampleToDataLogNormaliser                                    │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ dataLogs: [DataLog]
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogPipeline                                                            │
│  • ingest(logs: [DataLog])                                                  │
│  • Forwards to uploader.enqueueLogs()                                       │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ logs: [DataLog]
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  StreamingBatchProcessor                                                    │
│  • streamChunks(from: logs, handler)                                        │
│  • Groups by priority (critical > high > normal > low)                     │
│  • Chunks by size (maxChunkKB) and count (maxLogsPerChunk)                 │
│  • Calls handler for each chunk                                             │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ chunk: DataLogChunk
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogUploader                                                            │
│  • enqueue(chunk) → ChunkQueue                                              │
│  • runUploadLoop() → dequeues chunks                                        │
│  • uploadChunk() → checks NetworkMonitor & CircuitBreaker                  │
│  • If offline → persistBatch() to DeadLetterQueue                          │
│  • If online & circuit open → dataLogService.postDataLogs()                │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ requests: [DataLogRequest]
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogService                                                              │
│  • postDataLogs(requests)                                                   │
│  • Creates APIRequest → calls APIClient.send()                              │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ APIRequest
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  APIClient                                                                   │
│  • send(request) → executePipeline()                                        │
│  • buildNext() → interceptor chain (AuthorizationInterceptor)              │
│  • performRequest() → compressBodyIfNeeded() (if >1KB)                     │
│  • compressGzip() → adds GZIP header + deflate + CRC32 footer              │
│  • URLSession.data(for: urlRequest) → HTTP POST                            │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ HTTP POST (with GZIP if >1KB)
                           ▼
                    [Sahha API Server]
```

## 4. CIRCUIT BREAKER & NETWORK MONITOR INTEGRATION

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              RELIABILITY SYSTEM INTERACTIONS                                │
└─────────────────────────────────────────────────────────────────────────────┘

    [System: NWPathMonitor]
           │
           │ path.status changes
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  NetworkMonitor                                                             │
│  • handlePathUpdate(path) → updates isConnected                             │
│  • notifyStateChange(connected) → calls all registered callbacks            │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ onStateChange callback
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  CircuitBreaker                                                              │
│  • setNetworkMonitor(monitor) → registers callback                          │
│  • handleNetworkDisconnected() → state = .open                             │
│  • handleNetworkReconnected() → state = .halfOpen                          │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ shouldAllowRequest()
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogUploader                                                            │
│  • uploadChunk() checks:                                                    │
│    1. networkMonitor.shouldAttemptUpload() → if false, persist & wait     │
│    2. circuitBreaker.shouldAllowRequest() → if false, sleep & retry        │
│    3. dataLogService.postDataLogs() → attempt upload                       │
│  • On success → circuitBreaker.recordSuccess()                             │
│  • On failure → circuitBreaker.recordFailure()                             │
└─────────────────────────────────────────────────────────────────────────────┘

CIRCUIT BREAKER STATE MACHINE:

    [CLOSED] ──(N failures)──► [OPEN] ──(timeout/reconnect)──► [HALF_OPEN]
       ▲                              │                              │
       │                              │                              │
       └──(N successes)───────────────┴──(1 failure)────────────────┘

States:
  • CLOSED: Normal operation, requests allowed
  • OPEN: Too many failures, requests blocked (fail fast)
  • HALF_OPEN: Testing recovery, limited requests allowed
```

## 5. AUTHENTICATION FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AUTHENTICATION FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    [User calls Sahha.authenticate()]
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Sahha.swift                                                                 │
│  • authenticate(appId, appSecret, externalId, callback)                    │
│  • Calls actor.authManager()                                                │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  SahhaActor                                                                  │
│  • authManager() → resolve(AuthManagerProtocol)                             │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthManager                                                                 │
│  • authenticate(appId, appSecret, externalId)                               │
│  • Validates inputs (non-empty)                                             │
│  • Calls authService.authenticate()                                         │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthService                                                                 │
│  • authenticate(appId, appSecret, externalId)                               │
│  • Creates RegisterRequest                                                   │
│  • Calls APIClient.send(request) → POST /api/v2/auth/register              │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ HTTP POST
                           ▼
                    [Sahha API Server]
                           │
                           │ TokenResponse { profileToken, refreshToken }
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthManager                                                                 │
│  • tokenStore.saveToken(response)                                           │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TokenStore (KeychainStorage)                                               │
│  • saveToken(response) → stores in Keychain                                │
│  • Updates Sahha.authSnapshot.profileToken                                  │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  SahhaActor                                                                  │
│  • startAuthenticatedServices() → parallel execution:                      │
│    - startDataCollection() → HealthKitManager.resumeSensors()              │
│    - forceSyncDeviceInfo() → DeviceInfoSyncManager.forceSyncDeviceInfo()   │
│    - setupLifecycleListeners() → registers listeners                       │
│    - syncDemographic() → merges HealthKit demographic                      │
└─────────────────────────────────────────────────────────────────────────────┘

TOKEN REFRESH FLOW:

    [APIClient needs auth token]
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthorizationInterceptor                                                    │
│  • intercept(request, next)                                                 │
│  • Calls authManager.getValidProfileToken()                                 │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthManager                                                                 │
│  • getValidProfileToken()                                                   │
│  • tokenStore.token() → gets from Keychain                                  │
│  • JWT.isExpired(token, offset) → checks expiry                            │
│  • If expired → refreshToken(refreshToken)                                 │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ If expired
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthService                                                                 │
│  • refreshToken(refreshToken)                                               │
│  • POST /api/v2/auth/refresh                                                │
│  • Returns new TokenResponse                                                │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ New tokens
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AuthManager                                                                 │
│  • tokenStore.saveToken(newResponse)                                        │
│  • Returns new profileToken                                                 │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ Token added to request header
                           ▼
                    [Request continues with Authorization header]
```

## 6. DEAD LETTER QUEUE & PERSISTENCE FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PERSISTENCE & RETRY FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    [DataLogUploader.uploadChunk()]
           │
           │ Checks networkMonitor.shouldAttemptUpload()
           │
           ├───[OFFLINE]───────────────────────────────────────────────────────┐
           │                                                                   │
           ▼                                                                   │
┌─────────────────────────────────────────────────────────────────────────────┐│
│  DeadLetterQueue                                                             ││
│  • persistBatch(chunk, attemptCount, lastError: nil)                        ││
│  • Creates PersistedBatch { id, chunk, timestamp, attemptCount, lastError } ││
│  • Encodes to JSON                                                          ││
│  • Writes to: PersistentQueue/batch_{priority}_{timestamp}_{id}.json       ││
│  • cleanupOldBatches() → removes oldest if > maxStoredBatches (500)        ││
└─────────────────────────────────────────────────────────────────────────────┘│
           │                                                                   │
           │ File persisted                                                    │
           │                                                                   │
           └───────────────────────────────────────────────────────────────────┘
           │
           │ [Network reconnects OR App restarts]
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogUploader                                                             │
│  • loadPersistedData() → called on first startup                            │
│  • persistentQueue.loadAllBatches()                                         │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DeadLetterQueue                                                             │
│  • loadAllBatches()                                                         │
│  • Reads all .json files from PersistentQueue/                               │
│  • Decodes PersistedBatch objects                                           │
│  • Sorts by priority (high first), then timestamp (oldest first)            │
│  • Returns [PersistedBatch]                                                 │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ batches: [PersistedBatch]
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogUploader                                                             │
│  • chunkQueue.enqueue(batch.chunk, persistedId: batch.id)                   │
│  • Re-enqueues all persisted batches for retry                              │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           │ Chunks re-enter upload loop
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DataLogUploader                                                             │
│  • uploadChunk() → attempts upload again                                    │
│  • On success → persistentQueue.removeBatch(withId: id)                    │
│  • On max retries → persistBatch(chunk, attemptCount, lastError: message)   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 7. FUNCTION CALL HIERARCHY: Key Operations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FUNCTION CALL HIERARCHIES                                 │
└─────────────────────────────────────────────────────────────────────────────┘

A. SDK INITIALIZATION
─────────────────────
Sahha.configure(settings, callback)
  └─► SahhaActor.configure(with: settings)
      └─► DIContainer()
      └─► StorageDI.registerDependencies(container)
      └─► DeviceInfoDI.registerDependencies(container, settings)
      └─► NetworkingDI.registerDependencies(container, settings)
      └─► LoggingDI.registerDependencies(container)
      └─► AuthDI.registerDependencies(container)
      └─► DataLogDI.registerDependencies(container)
      └─► HealthKitDI.registerDependencies(container)
      └─► ... (other DI modules)
      └─► container.resolve(APIInterceptorStoreProtocol)
      └─► interceptorStore.addInterceptor(authInterceptor)
      └─► authManager.hasValidProfileToken()
          └─► [If valid] startAuthenticatedServices(container)

B. AUTHENTICATION
─────────────────
Sahha.authenticate(appId, appSecret, externalId, callback)
  └─► SahhaActor.authManager()
      └─► container.resolve(AuthManagerProtocol)
  └─► AuthManager.authenticate(appId, appSecret, externalId)
      └─► AuthService.authenticate(appId, appSecret, externalId)
          └─► APIClient.send(RegisterRequest)
              └─► executePipeline(request)
                  └─► AuthorizationInterceptor.intercept(request, next)
                      └─► [No token yet, skip]
                  └─► performRequest(request)
                      └─► buildURLRequest(from: request)
                      └─► compressBodyIfNeeded(urlRequest)
                      └─► URLSession.data(for: urlRequest)
      └─► TokenStore.saveToken(response)
          └─► KeychainStorage.save(key: "profileToken", value: token)
          └─► KeychainStorage.save(key: "refreshToken", value: token)
          └─► Sahha.authSnapshot.profileToken = token
  └─► SahhaActor.startAuthenticatedServices()
      └─► startDataCollection(container)
      └─► forceSyncDeviceInfo(container)
      └─► setupLifecycleListeners(container)
      └─► syncDemographic(container)

C. HEALTHKIT DATA COLLECTION
─────────────────────────────
HealthKitManager.resumeSensors()
  └─► sensorStore.getSensors()
  └─► HealthKitDataLogCoordinator.startDataLogCollection(for: sensors)
      └─► HealthKitObserverService.startObservers(for: sensors, handler)
          └─► [For each sensor] startObserver(for: sensor, handler)
              └─► permissions.hasPermissions(for: sensor)
              └─► HKObserverQuery(sampleType, predicate, updateHandler)
              └─► observerStore.addObserver(query, for: sensor)
              └─► healthStore.execute(query)

[HealthKit fires notification]
  └─► HKObserverQuery.updateHandler(query, completion, error)
      └─► [Check CircuitBreaker.isHealthy()]
      └─► handler(sensor, sampleType)
          └─► HealthKitDataLogCoordinator.launchTrackedQuery(sensor, sampleType)
              └─► runSensorQuery(for: sensor, sampleType)
                  └─► [Check CircuitBreaker.isHealthy() again]
                  └─► anchorStore.loadAnchor(for: sensor)
                  └─► anchorQueryService.runAnchorQuery(sampleType, anchor, limit)
                      └─► HKAnchoredObjectQuery → fetches [HKSample]
                  └─► normaliser.normalise(sample) → [DataLog]
                      └─► HKSampleToDataLogNormaliserRegistry.normalise(sample)
                          └─► [Select normaliser by sampleType.identifier]
                          └─► normaliser.normalise(sample) → [DataLog]
                  └─► dataLogPipeline.ingest(dataLogs)
                      └─► DataLogUploader.enqueueLogs(logs)
                          └─► StreamingBatchProcessor.streamChunks(from: logs, handler)
                              └─► processLogsIntoChunks(logs, handler)
                                  └─► [Group by priority]
                                  └─► streamPriorityGroup(logs, priority, handler)
                                      └─► [Chunk by size/count]
                                      └─► handler(chunk)
                                          └─► DataLogUploader.enqueue(chunk)
                                              └─► chunkQueue.enqueue(chunk)
                                              └─► startUploadLoopIfNeeded()
                                                  └─► loadPersistedData()
                                                  └─► runUploadLoop()
                                                      └─► uploadChunk(chunk)
                                                          └─► [Check networkMonitor.shouldAttemptUpload()]
                                                          └─► [Check circuitBreaker.shouldAllowRequest()]
                                                          └─► dataLogService.postDataLogs(chunk.requests)
                                                              └─► APIClient.send(request)
                                                                  └─► [GZIP compression if >1KB]
                                                                  └─► HTTP POST

D. ERROR HANDLING
──────────────────
[Any error occurs]
  └─► ErrorLogger.postError(error)
      └─► ErrorLoggingService.postError(error)
          └─► Creates ErrorLog { source, location, message, ... }
          └─► APIClient.send(ErrorLogRequest)
              └─► POST /api/v2/error

E. LIFECYCLE EVENTS
───────────────────
[App lifecycle event: app_resume, app_background, etc.]
  └─► LifecycleObserver.notifyListeners(event)
      └─► [For each registered listener]
          └─► DeviceInfoSyncLifecycleListener.handleLifecycleEvent(event)
              └─► DeviceInfoSyncManager.forceSyncDeviceInfo()
          └─► PostInsightsLifecycleListener.handleLifecycleEvent(event)
              └─► HealthKitManager.postInsights()
          └─► DeviceLogLifecycleListener.handleLifecycleEvent(event)
              └─► createAppLifecycleLog(for: event)
              └─► dataLogPipeline.ingest(log)
```

## 8. COMPONENT DEPENDENCY GRAPH

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEPENDENCY GRAPH (Who depends on whom)                   │
└─────────────────────────────────────────────────────────────────────────────┘

Sahha (Public API)
  └─► SahhaActor
      └─► DIContainer
          ├─► All Managers (Auth, HealthKit, Score, Biomarker, Demographic)
          ├─► All Services (Auth, DataLog, Score, Biomarker, Demographic)
          ├─► All Stores (Token, Sensor, Anchor, Observer)
          ├─► All Coordinators (HealthKitDataLog, HealthKitSahhaSample, etc.)
          └─► Core Components (APIClient, CircuitBreaker, NetworkMonitor, etc.)

AuthManager
  ├─► AuthService ──► APIClient
  ├─► TokenStore (KeychainStorage)
  └─► ErrorLogger

HealthKitManager
  ├─► HealthKitPermissionsService
  ├─► SensorStore
  ├─► HealthKitDataLogCoordinator
  │   ├─► HealthKitObserverService
  │   │   ├─► HKHealthStore (System)
  │   │   ├─► HealthKitObserverStore
  │   │   └─► CircuitBreaker (optional)
  │   ├─► HealthKitAnchorQueryService
  │   │   └─► HKHealthStore (System)
  │   ├─► HealthKitAnchorStore
  │   ├─► HKSampleToDataLogNormaliserRegistry
  │   │   └─► [Specific Normalisers]
  │   ├─► DataLogPipeline
  │   └─► CircuitBreaker (optional)
  ├─► HealthKitSahhaStatCoordinator
  ├─► HealthKitSahhaSampleCoordinator
  ├─► HealthKitDemographicService
  └─► ErrorLogger

DataLogUploader
  ├─► DataLogService ──► APIClient
  ├─► DataLogRequestMapper
  ├─► CircuitBreaker
  │   └─► NetworkMonitor (via setNetworkMonitor)
  ├─► NetworkMonitor
  │   └─► NWPathMonitor (System)
  ├─► DeadLetterQueue
  │   └─► FileManager (System)
  ├─► StreamingBatchProcessor
  │   ├─► DataLogRequestMapper
  │   └─► UploadPriorityAssigner
  └─► ErrorLogger

APIClient
  ├─► URLSession (System)
  └─► APIInterceptorStore
      └─► AuthorizationInterceptor
          └─► AuthManager

DataLogPipeline
  └─► DataLogUploader

CircuitBreaker
  └─► NetworkMonitor (optional, via callback)

NetworkMonitor
  └─► NWPathMonitor (System)
```

## 9. DATA STRUCTURES & MODELS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    KEY DATA STRUCTURES                                      │
└─────────────────────────────────────────────────────────────────────────────┘

DataLog
  ├─► logType: DataLogType (sleep, activity, heart, blood, etc.)
  ├─► dataType: String (e.g., "heart_rate", "steps")
  ├─► value: Double
  ├─► unit: String
  ├─► source: String (device/source ID)
  ├─► recordingMethod: RecordingMethod (automatic, manual)
  ├─► deviceType: String
  ├─► startDate: Date
  ├─► endDate: Date
  └─► additionalProperties: [String: String]? (optional metadata)

DataLogRequest (API format)
  ├─► deviceId: String
  ├─► [All DataLog fields]
  └─► [Mapped from DataLog by DataLogRequestMapper]

DataLogChunk
  ├─► requests: [DataLogRequest]
  ├─► sizeInBytes: Int
  └─► priority: UploadPriority (critical, high, normal, low)

PersistedBatch
  ├─► id: String (UUID)
  ├─► chunk: DataLogChunk
  ├─► timestamp: TimeInterval
  ├─► attemptCount: Int
  └─► lastError: String? (nil = offline, non-nil = failed)

TokenResponse
  ├─► profileToken: String (JWT)
  └─► refreshToken: String

APIRequest
  ├─► endpoint: String
  ├─► method: HTTPMethod (GET, POST, PUT, DELETE)
  ├─► body: Encodable?
  ├─► headers: [String: String]?
  └─► queryParameters: [URLQueryItem]?

APIResponse
  ├─► data: Data
  └─► response: HTTPURLResponse

CircuitState
  ├─► closed (normal)
  ├─► open (blocked)
  └─► halfOpen (testing)

SahhaSensor (enum)
  ├─► heart_rate, resting_heart_rate, heart_rate_variability_sdnn
  ├─► blood_glucose, blood_pressure_systolic, blood_pressure_diastolic
  ├─► sleep_analysis, steps, distance
  ├─► vo2_max, oxygen_saturation
  ├─► exercise, energy_burned
  └─► [Many more...]
```

## 10. CONCURRENCY MODEL (Actors & Tasks)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONCURRENCY ARCHITECTURE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

ACTORS (Thread-safe, isolated state):
─────────────────────────────────────
• SahhaActor ──► Orchestrates all operations
• DIContainer ──► Manages dependency resolution
• CircuitBreaker ──► State machine for failure handling
• NetworkMonitor ──► Network state tracking
• DeadLetterQueue ──► File-based persistence
• DataLogPipeline ──► Data ingestion
• DataLogUploader ──► Upload coordination
• StreamingBatchProcessor ──► Chunk processing
• HealthKitDataLogCoordinator ──► HealthKit query coordination
• HealthKitObserverStore ──► Observer management
• HealthKitAnchorStore ──► Anchor persistence
• ChunkQueue (private) ──► Priority queue for uploads

REGULAR CLASSES (Used within actors):
──────────────────────────────────────
• APIClient ──► Used by actors, but not an actor itself
• AuthManager ──► Used by actors
• HealthKitManager ──► Used by actors
• All Services ──► Used by actors
• All Normalisers ──► Used by actors

TASK COORDINATION:
──────────────────
• SingleTaskActors ──► Prevents duplicate concurrent operations
  - SingleThrowingTaskActor<T> ──► For operations that can throw
  - SingleTaskActorMap<K, V> ──► Per-key task deduplication

• AsyncSemaphore ──► Limits concurrent uploads
  - uploadSemaphore.wait() ──► Before upload
  - uploadSemaphore.signal() ──► After upload

PARALLEL OPERATIONS:
────────────────────
SahhaActor.startAuthenticatedServices():
  async let a = startDataCollection(container)
  async let b = forceSyncDeviceInfo(container)
  async let c = setupLifecycleListeners(container)
  async let d = syncDemographic(container)
  _ = await (a, b, c, d)  // All run in parallel
```

## 11. CONFIGURATION & SETTINGS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONFIGURATION STRUCTURE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

SahhaSettings
  ├─► environment: SahhaEnvironment
  │   ├─► sandbox → baseURL: "https://api.sandbox.sahha.ai"
  │   ├─► production → baseURL: "https://api.sahha.ai"
  │   └─► custom(baseURL: String)
  └─► [Other settings...]

UploadConfig (defaults)
  ├─► maxChunkKB: Int = 256
  ├─► maxLogsPerChunk: Int = 1000
  ├─► maxConcurrentUploads: Int = 3
  └─► maxRetries: Int = 5

CircuitBreaker (defaults)
  ├─► failureThreshold: Int = 5
  ├─► recoveryTimeout: TimeInterval = 60 seconds
  └─► halfOpenSuccessThreshold: Int = 2

DeadLetterQueue (defaults)
  └─► maxStoredBatches: Int = 500
```

## 12. FILE STRUCTURE OVERVIEW

```
Sources/Sahha/
├── Sahha.swift                    # Public API
├── SahhaActor.swift               # Orchestration
│
├── Core/
│   ├── DI/
│   │   └── DIContainer.swift      # Dependency injection
│   │
│   ├── API/
│   │   ├── Clients/
│   │   │   ├── APIClient.swift    # HTTP client + GZIP compression
│   │   │   └── BackgroundSessionDelegate.swift
│   │   ├── Interceptors/
│   │   │   └── AuthorizationInterceptor.swift
│   │   └── DI/NetworkingDI.swift
│   │
│   ├── Networking/
│   │   ├── CircuitBreaker.swift   # Failure protection
│   │   ├── NetworkMonitor.swift   # Connectivity monitoring
│   │   └── URLSessionFactory.swift
│   │
│   ├── Storage/
│   │   ├── Keychain/KeychainStorage.swift
│   │   └── UserDefaults/UserDefaultsStorage.swift
│   │
│   ├── Lifecycle/
│   │   └── Observers/LifecycleObserver.swift
│   │
│   └── [Other core utilities...]
│
└── Features/
    ├── Auth/
    │   ├── Managers/AuthManager.swift
    │   └── Services/AuthService.swift
    │
    ├── HealthKit/
    │   ├── Managers/HealthKitManager.swift
    │   ├── Observers/HealthKitObserverService.swift
    │   ├── Coordinators/
    │   │   └── DataLogs/HealthKitDataLogCoordinator.swift
    │   ├── Normalisers/
    │   │   └── DataLogs/ [Various normalisers]
    │   └── DI/HealthKitDI.swift
    │
    ├── DataLogs/
    │   ├── Pipelines/
    │   │   ├── DataLogPipeline.swift
    │   │   └── StreamingBatchProcessor.swift
    │   ├── Uploaders/DataLogUploader.swift
    │   ├── Queues/DeadLetterQueue.swift
    │   └── DI/DataLogDI.swift
    │
    └── [Other features...]
```

---

## SUMMARY

The Sahha iOS SDK is a well-architected, actor-based system with:

1. **Clear Separation of Concerns**: Public API → Orchestration → DI → Features
2. **Robust Reliability**: CircuitBreaker + NetworkMonitor + DeadLetterQueue
3. **Efficient Data Flow**: HealthKit → Normalisers → Pipeline → Uploader → API
4. **Proper Concurrency**: Actors for thread-safety, Tasks for async operations
5. **Comprehensive Error Handling**: ErrorLogger throughout, graceful degradation
6. **Persistence**: DeadLetterQueue for offline/failed data, Keychain for tokens
7. **Modularity**: DI container enables easy testing and swapping implementations

The architecture supports:
- ✅ Offline operation (data persisted, retried on reconnect)
- ✅ Failure resilience (circuit breaker prevents cascade failures)
- ✅ Priority-based uploads (critical data first)
- ✅ Efficient compression (GZIP for large payloads)
- ✅ Background data collection (HealthKit observers)
- ✅ Token refresh (automatic JWT renewal)

