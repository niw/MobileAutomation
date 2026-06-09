//
//  AppDelegate.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    let mainService: MainService

    private let backgroundAudioManager = BackgroundAudioManager()

    override init() {
        mainService = MainService()

        super.init()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundAudioManager.start()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        backgroundAudioManager.stop()
    }
}
