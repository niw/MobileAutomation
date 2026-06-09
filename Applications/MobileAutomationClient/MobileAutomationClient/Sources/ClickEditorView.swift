//
//  ClickEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import MobileAutomationSupport
import SwiftUI

struct ClickEditorView: View {
    var kind: CommandKind
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    init(kind: CommandKind = .click, initial: Command?, onCommit: @escaping (Command) -> Void) {
        precondition(kind == .click || kind == .absoluteClick)
        self.kind = kind
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: kind))
    }

    var body: some View {
        Form {
            if initial == nil {
                Section("Presets") {
                    ForEach(MouseButton.allCases, id: \.self) { button in
                        Button {
                            var command = working
                            command.mouseButton = button
                            onCommit(command)
                            dismiss()
                        } label: {
                            Label(button.displayName, systemImage: systemImage(for: button))
                        }
                    }
                }
            }
            Section("Button") {
                Picker("Mouse Button", selection: $working.mouseButton) {
                    ForEach(MouseButton.allCases, id: \.self) { button in
                        Text(button.displayName).tag(button)
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

    private var navigationTitle: String {
        let noun = kind == .absoluteClick ? "Absolute Click" : "Click"
        return "\(initial == nil ? "Add" : "Edit") \(noun)"
    }

    private func systemImage(for button: MouseButton) -> String {
        switch button {
        case .left: "cursorarrow.click"
        case .right: "cursorarrow.click.2"
        case .middle: "cursorarrow.motionlines"
        case .back: "chevron.left"
        case .forward: "chevron.right"
        }
    }
}

#Preview("Click") {
    NavigationStack {
        ClickEditorView(kind: .click, initial: nil) { _ in }
    }
}

#Preview("Absolute Click") {
    NavigationStack {
        ClickEditorView(kind: .absoluteClick, initial: nil) { _ in }
    }
}
