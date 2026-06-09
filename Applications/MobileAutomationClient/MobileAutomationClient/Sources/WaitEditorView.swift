//
//  WaitEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import MobileAutomationSupport
import SwiftUI

struct WaitEditorView: View {
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    init(initial: Command?, onCommit: @escaping (Command) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: .wait))
    }

    var body: some View {
        Form {
            Section("Duration") {
                Stepper(value: $working.waitMilliseconds, in: 10 ... 60_000, step: 50) {
                    HStack {
                        Text("Wait")
                        Spacer()
                        Text("\(working.waitMilliseconds) ms")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(initial == nil ? "Add Wait" : "Edit Wait")
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

#Preview("Wait") {
    NavigationStack {
        WaitEditorView(initial: nil) { _ in }
    }
}
