//
//  PreviewEnvironmentViewModifier.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 6/8/26.
//

import Foundation
import SwiftUI

struct PreviewEnvironmentViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(PreviewAgentService().eraseToAnyAgentService())
            .environment(PreviewAirPlayScreenshotService().eraseToAnyAirPlayScreenshotService())
    }
}

extension View {
    func previewEnvironment() -> some View {
        modifier(PreviewEnvironmentViewModifier())
    }
}
