//
//  FoundationModelSettingsSection.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct FoundationModelSettingsSection: View {
    var body: some View {
        Section {
            LabeledContent("Status") {
                FoundationModelAvailabilityLabel()
            }
        } header: {
            Text("Foundation Model")
        } footer: {
            Text("Runs on-device via Apple Intelligence. Tool-call behavior is on a best-effort basis depending on the on-device model version.")
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            FoundationModelSettingsSection()
        }
    }
}
