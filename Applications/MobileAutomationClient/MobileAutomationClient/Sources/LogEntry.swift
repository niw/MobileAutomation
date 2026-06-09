//
//  LogEntry.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation

struct LogEntry: Identifiable {
    enum Direction {
        case sent
        case received
        case info
        case error
    }

    var id: UInt64
    var timestamp: Date
    var direction: Direction
    var title: String
    var detail: String?
}

extension LogEntry.Direction {
    var displayName: String {
        switch self {
        case .sent: "Sent"
        case .received: "Received"
        case .info: "Info"
        case .error: "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .sent: "arrow.up.circle"
        case .received: "arrow.down.circle"
        case .info: "info.circle"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}
