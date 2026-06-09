//
//  BrailleChordEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import ActionSupport
import Foundation
import MobileAutomationSupport
import SwiftUI

struct BrailleChordEditorView: View {
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    init(initial: Command?, onCommit: @escaping (Command) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: .typeBrailleChord))
    }

    /// Perkins-style two-column layout: dots 1-3 on the left, 4-6 on the
    /// right, plus 7-8 underneath as thumb dots.
    private static let dotRows: [[Int]] = [
        [1, 4],
        [2, 5],
        [3, 6],
        [7, 8],
    ]

    var body: some View {
        Form {
            Section("Chord") {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        ForEach(Self.dotRows, id: \.self) { row in
                            HStack(spacing: 8) {
                                ForEach(row, id: \.self) { dot in
                                    dotToggle(dot)
                                }
                            }
                        }
                    }
                    Button {
                        working.brailleSpace.toggle()
                    } label: {
                        Label("Space", systemImage: "space")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(working.brailleSpace ? .accentColor : nil)

                    HStack {
                        Text(unicodePreview)
                            .font(.title2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            working.brailleDots.removeAll()
                            working.brailleSpace = false
                        } label: {
                            Label("Clear", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .disabled(working.brailleDots.isEmpty && !working.brailleSpace)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

            if initial == nil {
                Section("Quick Commands") {
                    quickRow([
                        QuickCommand("Prev", "chevron.left", .previousItem),
                        QuickCommand("Next", "chevron.right", .nextItem),
                        QuickCommand("Activate", "hand.tap", .simpleTap),
                    ])
                    quickRow([
                        QuickCommand("Home", "house", .home),
                        QuickCommand("Back", "arrow.uturn.backward", .escape),
                        QuickCommand("First", "arrow.up.to.line", .firstItem),
                        QuickCommand("Last", "arrow.down.to.line", .lastItem),
                    ])
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                Section {
                    NavigationLink {
                        BrailleCommandPickerView { command in
                            apply(command)
                            dismiss()
                        }
                    } label: {
                        Label("Browse All Commands", systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
        .navigationTitle(initial == nil ? "Add Braille Chord" : "Edit Braille Chord")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onCommit(working)
                    dismiss()
                } label: {
                    Label(initial == nil ? "Add" : "Save", systemImage: "checkmark")
                }
                .disabled(working.brailleDots.isEmpty && !working.brailleSpace)
            }
        }
    }

    private func dotToggle(_ dot: Int) -> some View {
        let isOn = working.brailleDots.contains(dot)
        return Button {
            if isOn {
                working.brailleDots.remove(dot)
            } else {
                working.brailleDots.insert(dot)
            }
        } label: {
            Text("\(dot)")
                .font(.title2.monospacedDigit().weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : nil)
    }

    private var unicodePreview: String {
        let glyph = BrailleChord(dots: working.brailleDots).brailleGlyph
        return working.brailleSpace ? "\(glyph) + ␣" : glyph
    }

    private struct QuickCommand {
        var title: String
        var systemImage: String
        var command: BrailleCommand

        init(_ title: String, _ systemImage: String, _ command: BrailleCommand) {
            self.title = title
            self.systemImage = systemImage
            self.command = command
        }
    }

    private func apply(_ command: BrailleCommand) {
        var built = working
        built.brailleDots = command.chord.dots
        built.brailleSpace = command.chord.space
        onCommit(built)
    }

    private func quickRow(_ commands: [QuickCommand]) -> some View {
        HStack(spacing: 8) {
            ForEach(commands, id: \.title) { command in
                Button {
                    apply(command.command)
                    dismiss()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: command.systemImage)
                            .font(.title3)
                        Text(command.title)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview("New") {
    NavigationStack {
        BrailleChordEditorView(initial: nil) { _ in }
    }
}

#Preview("Edit") {
    NavigationStack {
        BrailleChordEditorView(
            initial: Command(kind: .typeBrailleChord, brailleDots: [1, 2, 5], brailleSpace: true)
        ) { _ in }
    }
}
