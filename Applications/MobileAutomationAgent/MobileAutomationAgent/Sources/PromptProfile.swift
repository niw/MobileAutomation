//
//  PromptProfile.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import AgentSupport
import Foundation

enum PromptProfile: String, CaseIterable, Identifiable {
    case detailed

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .detailed: "Detailed"
        }
    }

    var systemPrompt: String {
        switch self {
        case .detailed: Self.detailedSystemPrompt
        }
    }

    var tools: [AgentTool] {
        switch self {
        case .detailed: Self.detailedTools
        }
    }
}
