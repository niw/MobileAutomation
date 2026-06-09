//
//  NotificationManager.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import UserNotifications

enum NotificationManager {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return
        }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func notifyFinished(success: Bool, summary: String?) async {
        let content = UNMutableNotificationContent()
        content.title = success ? "Agent finished" : "Agent could not complete"
        if let summary, !summary.isEmpty {
            content.body = summary
        } else {
            content.body = success ? "Goal achieved." : "Goal failed."
        }
        content.sound = .default
        await send(content: content)
    }

    static func notifyStopped() async {
        let content = UNMutableNotificationContent()
        content.title = "Agent stopped"
        content.body = "The agent loop ended without completing."
        content.sound = .default
        await send(content: content)
    }

    static func notifyError(message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Agent error"
        content.body = message
        content.sound = .default
        await send(content: content)
    }

    private static func send(content: UNNotificationContent) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .denied, .notDetermined:
            return
        @unknown default:
            return
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
