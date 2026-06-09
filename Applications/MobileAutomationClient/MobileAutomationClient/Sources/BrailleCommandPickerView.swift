//
//  BrailleCommandPickerView.swift
//  MobileAutomationClient
//

import ActionSupport
import SwiftUI

/// Browse every VoiceOver Braille command published by Apple
/// (https://support.apple.com/en-us/118665), grouped by category. Tapping a
/// row invokes `onSelect` with the chosen command — the caller is expected
/// to fold its chord into whatever editor state it owns and dismiss.
struct BrailleCommandPickerView: View {
    var onSelect: (BrailleCommand) -> Void

    var body: some View {
        List {
            ForEach(BrailleCommandCategory.allCases, id: \.self) { category in
                Section(category.displayName) {
                    ForEach(BrailleCommand.commands(in: category), id: \.self) { command in
                        Button {
                            onSelect(command)
                        } label: {
                            row(for: command)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Braille Commands")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for command: BrailleCommand) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.displayName)
                    .foregroundStyle(.primary)
                Text(command.chord.displayString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(command.chord.brailleGlyph)
                .font(.title2.monospaced())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        BrailleCommandPickerView { _ in }
    }
}
