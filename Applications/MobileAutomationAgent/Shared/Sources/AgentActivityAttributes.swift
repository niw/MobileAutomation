//
//  AgentActivityAttributes.swift
//  Shared
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import ActivityKit
import Foundation

struct AgentActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var statusText: String
        var lastUpdate: String?
        var step: Int
        var isFinished: Bool
        var success: Bool?
    }

    var goal: String
}
