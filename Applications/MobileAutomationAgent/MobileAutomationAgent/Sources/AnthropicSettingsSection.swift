//
//  AnthropicSettingsSection.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct AnthropicSettingsSection: View {
    @Binding
    var errorMessage: String?

    @AppStorage(Configuration.UserDefaultsKey.anthropicModel)
    private var model: String?

    @AppStorage(Configuration.UserDefaultsKey.agentMaxTokens)
    private var maxTokens: Int?

    var body: some View {
        ApiKeySecureField(
            title: "Anthropic API Key",
            placeholder: "sk-ant-...",
            keyName: .anthropic,
            errorMessage: $errorMessage
        )

        Section {
            LabeledContent("Model") {
                TextField(
                    Configuration.Defaults.anthropicModel,
                    text: Binding(
                        get: { model ?? "" },
                        set: { value in
                            model = (value == "") ? nil : value
                        }
                    )
                )
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            LabeledContent("Max Tokens") {
                TextField(
                    "\(Configuration.Defaults.agentMaxTokens)",
                    value: Binding(
                        get: { maxTokens },
                        set: { maxTokens = $0 }
                    ),
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Anthropic")
        }
    }
}

#Preview {
    @Previewable @State
    var errorMessage: String?
    NavigationStack {
        Form {
            AnthropicSettingsSection(errorMessage: $errorMessage)
        }
    }
}
