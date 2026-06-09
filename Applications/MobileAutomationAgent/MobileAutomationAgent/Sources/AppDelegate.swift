//
//  AppDelegate.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import UIKit
import UserNotifications

final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let airPlayScreenshotService: AirPlayScreenshotService
    let agentService: AgentService

    private let backgroundAudioManager = BackgroundAudioManager()

    override init() {
        let airPlayScreenshotService = AirPlayScreenshotService()
        self.airPlayScreenshotService = airPlayScreenshotService
        agentService = AgentService(
            screenCapture: { settle in
                await airPlayScreenshotService.capture(settle: settle, scale: 0.5)
            },
            sourceSize: {
                await airPlayScreenshotService.sourceSize
            }
        )

        super.init()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        airPlayScreenshotService.start()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundAudioManager.start()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        backgroundAudioManager.stop()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
