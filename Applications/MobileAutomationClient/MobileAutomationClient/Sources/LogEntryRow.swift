//
//  LogEntryRow.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct LogEntryRow: View {
    var entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.direction.systemImage)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.title)
                        .font(.callout)
                    Spacer()
                    Text(Self.timeFormatter.string(from: entry.timestamp))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let detail = entry.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var color: Color {
        switch entry.direction {
        case .sent: .blue
        case .received: .green
        case .info: .secondary
        case .error: .red
        }
    }
}
