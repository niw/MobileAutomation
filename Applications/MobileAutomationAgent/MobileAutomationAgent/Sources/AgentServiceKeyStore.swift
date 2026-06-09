//
//  AgentServiceKeyStore.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import AppSupport
import Foundation

@MainActor
enum AgentServiceKeyStore {
    enum Name: String {
        case anthropic = "anthropic-api-key"
        case openai = "openai-api-key"
    }

    private static let storage: any TokenStorage = KeychainTokenStorage(
        service: Bundle.main.bundleIdentifier!
    )

    static func read(for name: Name) throws -> String? {
        try storage.read(for: name.rawValue)
    }

    static func write(_ value: String, for name: Name) throws {
        try storage.write(value, for: name.rawValue)
    }

    static func delete(name: Name) throws {
        try storage.delete(key: name.rawValue)
    }
}
