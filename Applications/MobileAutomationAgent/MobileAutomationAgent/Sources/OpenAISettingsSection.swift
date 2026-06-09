//
//  OpenAISettingsSection.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct OpenAISettingsSection: View {
    @Binding
    var errorMessage: String?

    @AppStorage(Configuration.UserDefaultsKey.openaiModel)
    private var model: String?

    @AppStorage(Configuration.UserDefaultsKey.agentMaxTokens)
    private var maxTokens: Int?

    var body: some View {
        ApiKeySecureField(
            title: "OpenAI API Key",
            placeholder: "sk-...",
            keyName: .openai,
            errorMessage: $errorMessage
        )

        Section {
            LabeledContent("Model") {
                TextField(
                    Configuration.Defaults.openaiModel,
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
            LabeledContent("Max Output Tokens") {
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
            Text("OpenAI")
        } footer: {
            Text("Uses the Responses API endpoint (v1/responses).")
        }
    }
}

#Preview {
    @Previewable @State
    var errorMessage: String?
    NavigationStack {
        Form {
            OpenAISettingsSection(errorMessage: $errorMessage)
        }
    }
}
