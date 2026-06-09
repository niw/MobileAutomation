//
//  CommandRow.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct CommandRow: View {
    var command: Command

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.kind.displayName)
                    .font(.body)
                Text(command.summary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } icon: {
            Image(systemName: command.kind.systemImage)
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    List {
        ForEach(PreviewMainService.sampleCommands) { command in
            CommandRow(command: command)
        }
    }
}
