//
//  TypeTextEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import MobileAutomationSupport
import SwiftUI

struct TypeTextEditorView: View {
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    init(initial: Command?, onCommit: @escaping (Command) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: .typeText))
    }

    var body: some View {
        Form {
            Section("Text") {
                TextField("Text to type", text: $working.text, axis: .vertical)
                    .lineLimit(3 ... 10)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section {
                Text("Only ASCII letters, digits, space, return, and tab are supported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(initial == nil ? "Add Type Text" : "Edit Type Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onCommit(working)
                    dismiss()
                } label: {
                    Label(initial == nil ? "Add" : "Save", systemImage: "checkmark")
                }
                .disabled(working.text.isEmpty)
            }
        }
    }
}

#Preview("Type Text") {
    NavigationStack {
        TypeTextEditorView(initial: nil) { _ in }
    }
}
