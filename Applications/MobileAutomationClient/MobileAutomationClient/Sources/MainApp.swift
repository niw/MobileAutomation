//
//  MainApp.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI

@main
struct MainApp: App {
    @UIApplicationDelegateAdaptor
    private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .appDelegateEnvironment(appDelegate: appDelegate)
        }
    }
}
