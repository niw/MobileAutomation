//
//  AbsoluteMouseEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/21/26.
//

import Foundation
import MobileAutomationSupport
import SwiftUI

/// Editor for `.moveAbsoluteMouse`. Logical coordinate range is
/// `0...absoluteMouseLogicalMax` on both axes. In new-mode a 3×3 grid of
/// quick-position buttons commits immediately so testing corner / centre
/// positioning is one tap.
struct AbsoluteMouseEditorView: View {
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    private static let stepperStep: Int = 256

    init(initial: Command?, onCommit: @escaping (Command) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: .moveAbsoluteMouse))
    }

    var body: some View {
        Form {
            if initial == nil {
                Section("Quick Positions") {
                    quickGrid
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Manual") {
                Stepper(
                    value: $working.absX,
                    in: 0 ... absoluteMouseLogicalMax,
                    step: Self.stepperStep
                ) {
                    HStack {
                        Text("x")
                        Spacer()
                        Text("\(working.absX)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(
                    value: $working.absY,
                    in: 0 ... absoluteMouseLogicalMax,
                    step: Self.stepperStep
                ) {
                    HStack {
                        Text("y")
                        Spacer()
                        Text("\(working.absY)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Range 0…\(absoluteMouseLogicalMax)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(initial == nil ? "Add Move Absolute Mouse" : "Edit Move Absolute Mouse")
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

    private var quickGrid: some View {
        let lo = 0
        let mid = absoluteMouseLogicalMax / 2
        let hi = absoluteMouseLogicalMax
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                quickButton("arrow.up.left", x: lo, y: lo)
                quickButton("arrow.up", x: mid, y: lo)
                quickButton("arrow.up.right", x: hi, y: lo)
            }
            HStack(spacing: 8) {
                quickButton("arrow.left", x: lo, y: mid)
                quickButton("scope", x: mid, y: mid)
                quickButton("arrow.right", x: hi, y: mid)
            }
            HStack(spacing: 8) {
                quickButton("arrow.down.left", x: lo, y: hi)
                quickButton("arrow.down", x: mid, y: hi)
                quickButton("arrow.down.right", x: hi, y: hi)
            }
        }
    }

    private func quickButton(_ systemImage: String, x: Int, y: Int) -> some View {
        DPadButton(systemImage: systemImage) {
            var command = working
            command.absX = x
            command.absY = y
            onCommit(command)
            dismiss()
        }
    }
}

#Preview("Absolute Mouse — New") {
    NavigationStack {
        AbsoluteMouseEditorView(initial: nil) { _ in }
    }
}

#Preview("Absolute Mouse — Edit") {
    NavigationStack {
        AbsoluteMouseEditorView(initial: Command(kind: .moveAbsoluteMouse, absX: 4096, absY: 12000)) { _ in }
    }
}
