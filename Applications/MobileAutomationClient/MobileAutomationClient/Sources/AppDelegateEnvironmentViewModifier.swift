//
//  AppDelegateEnvironmentViewModifier.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 45/18/26.
//

import Foundation
import SwiftUI
import UIKit

struct AppDelegateEnvironmentViewModifier: ViewModifier {
    var appDelegate: AppDelegate

    func body(content: Content) -> some View {
        content
            .environment(appDelegate.mainService.eraseToAnyMainService())
    }
}

extension View {
    func appDelegateEnvironment(appDelegate: AppDelegate) -> some View {
        modifier(AppDelegateEnvironmentViewModifier(appDelegate: appDelegate))
    }
}
