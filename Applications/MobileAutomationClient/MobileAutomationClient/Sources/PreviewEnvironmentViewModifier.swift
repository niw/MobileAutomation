//
//  PreviewEnvironmentViewModifier.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI

struct PreviewEnvironmentViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(PreviewMainService().eraseToAnyMainService())
    }
}

extension View {
    func previewEnvironment() -> some View {
        modifier(PreviewEnvironmentViewModifier())
    }
}
