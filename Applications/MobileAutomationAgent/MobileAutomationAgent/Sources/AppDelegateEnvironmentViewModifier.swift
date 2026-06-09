//
//  AppDelegateEnvironmentViewModifier.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI
import UIKit

struct AppDelegateEnvironmentViewModifier: ViewModifier {
    var appDelegate: AppDelegate

    func body(content: Content) -> some View {
        content
            .environment(appDelegate.agentService.eraseToAnyAgentService())
            .environment(appDelegate.airPlayScreenshotService.eraseToAnyAirPlayScreenshotService())
    }
}

extension View {
    func appDelegateEnvironment(appDelegate: AppDelegate) -> some View {
        modifier(AppDelegateEnvironmentViewModifier(appDelegate: appDelegate))
    }
}
