//
//  FoundationModelAvailabilityLabel.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import FoundationModels
import SwiftUI

struct FoundationModelAvailabilityLabel: View {
    private let model = SystemLanguageModel.default

    var body: some View {
        switch model.availability {
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        case .unavailable(.deviceNotEligible):
            unavailableLabel("Device not eligible")
        case .unavailable(.appleIntelligenceNotEnabled):
            unavailableLabel("Apple Intelligence not enabled")
        case .unavailable(.modelNotReady):
            unavailableLabel("Model downloading…")
        case .unavailable:
            unavailableLabel("Unavailable")
        }
    }

    private func unavailableLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.orange)
    }
}

#Preview {
    Form {
        LabeledContent("Status") {
            FoundationModelAvailabilityLabel()
        }
    }
}
