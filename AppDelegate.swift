// Copyright © 2022 Sahha. All rights reserved.

import UIKit
import Sahha

/// AppDelegate to handle background URLSession events for Sahha uploads
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        print("[Demo App] Handling background session events for: \(identifier)")
        
        // Forward to Sahha SDK
        Sahha.handleBackgroundSessionEvents(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register the background task
        Sahha.registerBackgroundRefreshTask(identifier: "com.sahha.background_refresh")
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule the background task when entering background
        Sahha.scheduleBackgroundRefreshTask(identifier: "com.sahha.background_refresh")
    }
}

