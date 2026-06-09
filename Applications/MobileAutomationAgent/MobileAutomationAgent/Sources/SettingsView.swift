//
//  SettingsView.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State
    private var errorMessage: String?

    @AppStorage(Configuration.UserDefaultsKey.provider)
    private var providerRaw: String?

    @AppStorage(Configuration.UserDefaultsKey.promptProfile)
    private var promptProfileRaw: String?

    @AppStorage(Configuration.UserDefaultsKey.agentMaxSteps)
    private var agentMaxSteps: Int?

    private var provider: AgentProvider {
        providerRaw.flatMap(AgentProvider.init(rawValue:)) ?? Configuration.Defaults.provider
    }

    private var promptProfile: PromptProfile {
        promptProfileRaw.flatMap(PromptProfile.init(rawValue:)) ?? Configuration.Defaults.promptProfile
    }

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: providerBinding) {
                    ForEach(AgentProvider.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
            } header: {
                Text("Provider")
            } footer: {
                Text("Anthropic and OpenAI go through their cloud APIs. Foundation Model runs on-device via Apple Intelligence.")
            }

            switch provider {
            case .anthropic:
                AnthropicSettingsSection(errorMessage: $errorMessage)
            case .openai:
                OpenAISettingsSection(errorMessage: $errorMessage)
            case .foundationModel:
                FoundationModelSettingsSection()
            }

            Section {
                Picker("Prompt", selection: promptProfileBinding) {
                    ForEach(PromptProfile.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                LabeledContent("Max Steps") {
                    TextField(
                        "\(Configuration.Defaults.agentMaxSteps)",
                        value: Binding(
                            get: { agentMaxSteps },
                            set: { agentMaxSteps = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Agent")
            } footer: {
                Text("Detailed ships full recipes; Concise trims the brief for compact-context models like Foundation Model. Applies to the next run.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var providerBinding: Binding<AgentProvider> {
        Binding(
            get: { provider },
            set: { newValue in
                providerRaw = newValue.rawValue
            }
        )
    }

    private var promptProfileBinding: Binding<PromptProfile> {
        Binding(
            get: { promptProfile },
            set: { newValue in
                promptProfileRaw = newValue.rawValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
