//
//  MoveScrollEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

/// Drives both `.moveMouse` and `.scrollMouse`. The two commands have the
/// same shape (dx/dy deltas) and differ only in labels and the underlying
/// Client API the runner calls; folding them into one editor keeps the D-Pad
/// UI in a single place.
struct MoveScrollEditorView: View {
    var kind: CommandKind
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @State
    private var step: Double = 30

    @Environment(\.dismiss)
    private var dismiss

    init(
        kind: CommandKind,
        initial: Command?,
        onCommit: @escaping (Command) -> Void
    ) {
        precondition(kind == .moveMouse || kind == .scrollMouse || kind == .scrollAbsoluteMouse)
        self.kind = kind
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: kind))
    }

    var body: some View {
        Form {
            if initial == nil {
                Section("Step") {
                    HStack {
                        Slider(value: $step, in: 5 ... 120, step: 5)
                        Text("\(Int(step)) px")
                            .font(.caption.monospacedDigit())
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Section("Direction") {
                    VStack(spacing: 8) {
                        DPadButton(systemImage: "arrow.up") {
                            commitDelta(dx: 0, dy: -Int(step))
                        }
                        HStack(spacing: 8) {
                            DPadButton(systemImage: "arrow.left") {
                                commitDelta(dx: -Int(step), dy: 0)
                            }
                            DPadButton(systemImage: "circle") {
                                // No-op slot; keeps the D-Pad symmetric.
                            }
                            .disabled(true)
                            DPadButton(systemImage: "arrow.right") {
                                commitDelta(dx: Int(step), dy: 0)
                            }
                        }
                        DPadButton(systemImage: "arrow.down") {
                            commitDelta(dx: 0, dy: Int(step))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Section(manualSectionTitle) {
                Stepper(
                    value: $working.dx,
                    in: -1000 ... 1000,
                    step: 10
                ) {
                    HStack {
                        Text(xLabel)
                        Spacer()
                        Text("\(working.dx)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(
                    value: $working.dy,
                    in: -1000 ... 1000,
                    step: 10
                ) {
                    HStack {
                        Text(yLabel)
                        Spacer()
                        Text("\(working.dy)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onCommit(working)
                    dismiss()
                } label: {
                    Label(initial == nil ? "Add" : "Save", systemImage: "checkmark")
                }
            }
        }
    }

    private func commitDelta(dx: Int, dy: Int) {
        var command = working
        command.dx = dx
        command.dy = dy
        onCommit(command)
        dismiss()
    }

    private var navigationTitle: String {
        switch (kind, initial) {
        case (.moveMouse, .none): "Add Move Mouse"
        case (.moveMouse, .some): "Edit Move Mouse"
        case (.scrollMouse, .none): "Add Scroll"
        case (.scrollMouse, .some): "Edit Scroll"
        case (.scrollAbsoluteMouse, .none): "Add Absolute Scroll"
        case (.scrollAbsoluteMouse, .some): "Edit Absolute Scroll"
        default: "Editor"
        }
    }

    private var manualSectionTitle: String {
        kind == .moveMouse ? "Manual" : "Delta"
    }

    private var xLabel: String {
        kind == .moveMouse ? "dx" : "Horizontal"
    }

    private var yLabel: String {
        kind == .moveMouse ? "dy" : "Vertical"
    }
}

#Preview("Move — New") {
    NavigationStack {
        MoveScrollEditorView(kind: .moveMouse, initial: nil) { _ in }
    }
}

#Preview("Scroll — New") {
    NavigationStack {
        MoveScrollEditorView(kind: .scrollMouse, initial: nil) { _ in }
    }
}
