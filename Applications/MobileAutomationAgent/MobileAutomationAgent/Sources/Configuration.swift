//
//  Configuration.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation

/// Which language-model backend drives the agent loop. Stored as a raw
/// string in `UserDefaults` so future cases (e.g. `.openai`) just slot in.
enum AgentProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openai
    case foundationModel

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .foundationModel: "Foundation Model"
        }
    }
}

enum Configuration {
    enum UserDefaultsKey {
        static let provider = "agentProvider"
        static let promptProfile = "agentPromptProfile"
        static let anthropicModel = "anthropicModel"
        static let openaiModel = "openaiModel"
        static let agentMaxSteps = "agentMaxSteps"
        static let agentMaxTokens = "agentMaxTokens"
        static let lastGoal = "agentLastGoal"
    }

    enum Defaults {
        static let provider: AgentProvider = .anthropic
        static let promptProfile: PromptProfile = .detailed
        static let anthropicModel = "claude-opus-4-8"
        static let openaiModel = "gpt-5"
        static let agentMaxSteps = 30
        static let agentMaxTokens = 4096
    }

    static var provider: AgentProvider {
        if let value = UserDefaults.standard.value(forKey: UserDefaultsKey.provider) as? String,
           let provider = AgentProvider(rawValue: value)
        {
            provider
        } else {
            Defaults.provider
        }
    }

    static var promptProfile: PromptProfile {
        if let value = UserDefaults.standard.value(forKey: UserDefaultsKey.promptProfile) as? String,
           let profile = PromptProfile(rawValue: value)
        {
            profile
        } else {
            Defaults.promptProfile
        }
    }

    static var anthropicModel: String {
        if let value = UserDefaults.standard.value(forKey: UserDefaultsKey.anthropicModel) as? String {
            value
        } else {
            Defaults.anthropicModel
        }
    }

    static var openaiModel: String {
        if let value = UserDefaults.standard.value(forKey: UserDefaultsKey.openaiModel) as? String {
            value
        } else {
            Defaults.openaiModel
        }
    }

    static var agentMaxSteps: Int {
        if let value = UserDefaults.standard.value(forKey: UserDefaultsKey.agentMaxSteps) as? Int {
            value
        } else {
            Defaults.agentMaxSteps
        }
    }

    static var agentMaxTokens: Int {
        if let value = UserDefaults.standard.value(forKey: UserDefaultsKey.agentMaxTokens) as? Int {
            value
        } else {
            Defaults.agentMaxTokens
        }
    }

    static var lastGoal: String {
        get {
            UserDefaults.standard.string(forKey: UserDefaultsKey.lastGoal) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastGoal)
        }
    }
}
