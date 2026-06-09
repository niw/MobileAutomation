//
//  TranscriptRow.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import AgentSupport
import Foundation
import SwiftUI

struct TranscriptRow: View {
    var entry: TurnEntry

    var body: some View {
        switch entry {
        case .userGoal(_, let text):
            row(label: "Goal", color: .blue, body: text)
        case .assistantText(_, let text):
            row(label: "Agent", color: .purple, body: text)
        case .toolUse(_, _, let name, let input):
            row(
                label: "tool",
                color: .indigo,
                body: "\(name)(\(Self.compactJSON(input)))"
            )
        case .toolResult(_, _, let name, let content, let isError, let image):
            row(
                label: isError ? "tool ✗" : "tool →",
                color: isError ? .red : .green,
                body: "\(name): \(content)",
                image: image
            )
        case .finished(_, let summary, let success, let stopReason):
            let label = success == true ? "Done" : (success == false ? "Failed" : "Stop")
            let color: Color = success == true ? .green : (success == false ? .red : .orange)
            let body = summary?.isEmpty == false ? summary! : "stop_reason: \(stopReason)"
            row(label: label, color: color, body: body)
        case .error(_, let message):
            row(label: "Error", color: .red, body: message)
        }
    }

    private func row(label: String, color: Color, body: String, image: UIImage? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(body)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 2)
    }

    static func compactJSON(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
