//
//  TapKeyEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import ActionSupport
import Foundation
import MobileAutomationSupport
import SwiftUI

struct TapKeyEditorView: View {
    var initial: Command?
    var onCommit: (Command) -> Void

    @State
    private var working: Command

    @Environment(\.dismiss)
    private var dismiss

    init(initial: Command?, onCommit: @escaping (Command) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _working = State(initialValue: initial ?? Command(kind: .tapKey))
    }

    var body: some View {
        Form {
            if initial == nil {
                Section("Presets") {
                    presetGrid(Self.basicPresets)
                    presetGrid(Self.navigationPresets)
                    presetGrid(Self.systemPresets)
                    presetGrid(Self.voiceOverPresets)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            Section("Key") {
                Stepper(
                    value: $working.keyUsage,
                    in: 0 ... 127
                ) {
                    HStack {
                        Text("Usage")
                        Spacer()
                        Text(String(format: "0x%02X", working.keyUsage))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Modifiers") {
                Toggle("Left Ctrl", isOn: modifierBinding(.leftControl))
                Toggle("Left Shift", isOn: modifierBinding(.leftShift))
                Toggle("Left Alt", isOn: modifierBinding(.leftAlt))
                Toggle("Left GUI", isOn: modifierBinding(.leftGUI))
                Toggle("Right Ctrl", isOn: modifierBinding(.rightControl))
                Toggle("Right Shift", isOn: modifierBinding(.rightShift))
                Toggle("Right Alt", isOn: modifierBinding(.rightAlt))
            }
        }
        .navigationTitle(initial == nil ? "Add Tap Key" : "Edit Tap Key")
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

    private func modifierBinding(_ flag: KeyboardModifier) -> Binding<Bool> {
        Binding(
            get: { working.keyModifiers.contains(flag) },
            set: { newValue in
                if newValue {
                    working.keyModifiers.insert(flag)
                } else {
                    working.keyModifiers.remove(flag)
                }
            }
        )
    }

    private func presetGrid(_ row: [Preset]) -> some View {
        HStack(spacing: 8) {
            ForEach(row, id: \.label) { preset in
                KeyButton(preset.label, systemImage: preset.systemImage) {
                    var command = working
                    command.keyUsage = preset.usage
                    command.keyModifiers = preset.modifiers
                    onCommit(command)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Preset data

    private struct Preset {
        var label: String
        var systemImage: String
        var usage: UInt8
        var modifiers: KeyboardModifier

        init(label: String, systemImage: String, usage: UInt8, modifiers: KeyboardModifier) {
            self.label = label
            self.systemImage = systemImage
            self.usage = usage
            self.modifiers = modifiers
        }

        /// Build a `Preset` from a named `KeyboardCommand`, so the
        /// (usage, modifiers) pair stays in sync with the agent and any
        /// other caller. Only the on-screen label / icon live here.
        init(_ shortcut: KeyboardCommand, label: String, systemImage: String) {
            let (usage, modifiers) = shortcut.keyEvent
            self.init(label: label, systemImage: systemImage, usage: usage, modifiers: modifiers)
        }
    }

    private static let basicPresets: [Preset] = [
        Preset(label: "Tab", systemImage: "arrow.right.to.line.compact", usage: 0x2B, modifiers: []),
        Preset(label: "Return", systemImage: "return", usage: 0x28, modifiers: []),
        Preset(label: "Esc", systemImage: "escape", usage: 0x29, modifiers: []),
        Preset(label: "Space", systemImage: "space", usage: 0x2C, modifiers: []),
    ]

    private static let navigationPresets: [Preset] = [
        Preset(label: "Left", systemImage: "arrow.left", usage: 0x50, modifiers: []),
        Preset(label: "Up", systemImage: "arrow.up", usage: 0x52, modifiers: []),
        Preset(label: "Down", systemImage: "arrow.down", usage: 0x51, modifiers: []),
        Preset(label: "Right", systemImage: "arrow.right", usage: 0x4F, modifiers: []),
    ]

    private static let systemPresets: [Preset] = [
        Preset(.home, label: "Home", systemImage: "house"),
        Preset(.appSwitcher, label: "Switcher", systemImage: "rectangle.on.rectangle"),
        Preset(.spotlight, label: "Spotlight", systemImage: "magnifyingglass"),
        Preset(label: "Delete", systemImage: "delete.left", usage: 0x2A, modifiers: []),
    ]

    private static let voiceOverPresets: [Preset] = [
        Preset(.voiceOverNext, label: "VO →", systemImage: "chevron.right.2"),
        Preset(.voiceOverPrevious, label: "VO ←", systemImage: "chevron.left.2"),
        Preset(.voiceOverActivate, label: "VO Tap", systemImage: "hand.tap"),
        Preset(.voiceOverEscape, label: "VO Esc", systemImage: "xmark.circle"),
    ]
}

#Preview("New") {
    NavigationStack {
        TapKeyEditorView(initial: nil) { _ in }
    }
}

#Preview("Edit") {
    NavigationStack {
        TapKeyEditorView(
            initial: Command(kind: .tapKey, keyUsage: 0x0B, keyModifiers: .leftGUI)
        ) { _ in }
    }
}
