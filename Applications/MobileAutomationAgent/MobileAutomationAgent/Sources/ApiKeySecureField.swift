//
//  ApiKeySecureField.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct ApiKeySecureField: View {
    var title: String
    var placeholder: String
    var keyName: AgentServiceKeyStore.Name

    @Binding
    var errorMessage: String?

    @State
    private var apiKey: String = ""

    @State
    private var hasStoredKey: Bool = false

    var body: some View {
        Section {
            SecureField(placeholder, text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: apiKey) { _, newValue in
                    updateApiKey(newValue)
                }
        } header: {
            Text(title)
        } footer: {
            if hasStoredKey {
                Text("Stored in the Keychain.")
            } else {
                Text("Not stored.")
            }
        }
        .onAppear {
            loadKey()
        }
    }

    private func loadKey() {
        do {
            if let value = try AgentServiceKeyStore.read(for: keyName) {
                apiKey = value
                hasStoredKey = true
            } else {
                apiKey = ""
                hasStoredKey = false
            }
        } catch {
            apiKey = ""
            hasStoredKey = false
            errorMessage = error.localizedDescription
        }
    }

    private func updateApiKey(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmedValue.isEmpty {
                try AgentServiceKeyStore.delete(name: keyName)
                hasStoredKey = false
            } else {
                try AgentServiceKeyStore.write(trimmedValue, for: keyName)
                hasStoredKey = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    @Previewable @State
    var errorMessage: String?
    NavigationStack {
        Form {
            ApiKeySecureField(
                title: "API Key",
                placeholder: "sk-...",
                keyName: .anthropic,
                errorMessage: $errorMessage
            )
        }
    }
}
