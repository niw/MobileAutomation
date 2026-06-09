//
//  RoutingKeyEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import MobileAutomationSupport
import SwiftUI

struct RoutingKeyEditorView: View {
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    init(initial: Command?, onCommit: @escaping (Command) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: .tapRoutingKey))
    }

    var body: some View {
        Form {
            Section("Routing Key Index") {
                Stepper(value: $working.routingIndex, in: 0 ... 39) {
                    HStack {
                        Text("Index")
                        Spacer()
                        Text("\(working.routingIndex)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Slider(
                    value: Binding(
                        get: { Double(working.routingIndex) },
                        set: { working.routingIndex = Int($0) }
                    ),
                    in: 0 ... 39,
                    step: 1
                )
            }
        }
        .navigationTitle(initial == nil ? "Add Routing Key" : "Edit Routing Key")
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
}

#Preview("Routing Key") {
    NavigationStack {
        RoutingKeyEditorView(initial: nil) { _ in }
    }
}
