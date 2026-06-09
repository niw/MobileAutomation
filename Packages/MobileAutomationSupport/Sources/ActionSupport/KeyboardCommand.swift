//
//  KeyboardCommand.swift
//  ActionSupport
//
//  Created by Yoshimasa Niwa on 5/19/26.
//
//  Note: named `KeyboardCommand` rather than `KeyboardShortcut` to
//  avoid colliding with SwiftUI's `KeyboardShortcut`.
//

import Foundation

/// Logical grouping for `KeyboardCommand`, mirroring how Apple
/// documents iPhone external-keyboard shortcuts.
///
/// Source: https://support.apple.com/guide/iphone/control-iphone-with-an-external-keyboard-ipha4375873f/
public enum KeyboardCommandCategory: String, Sendable, CaseIterable, Codable {
    case system
    case voiceOver
    case editing

    public var displayName: String {
        switch self {
        case .system: "System"
        case .voiceOver: "VoiceOver"
        case .editing: "Editing"
        }
    }
}

/// Named keyboard shortcuts for iPhone / iPad with an external keyboard.
///
/// The raw value is a snake_case identifier suitable for tool / API
/// payloads. Each case resolves to a HID Usage ID plus modifier mask
/// via `keyEvent`. Cmd-based combos rather than Globe-key combos are
/// used so the shortcuts work over the standard HID profile this
/// project's firmware exposes.
public enum KeyboardCommand: String, Sendable, CaseIterable, Codable {
    // System
    case home
    case appSwitcher = "app_switcher"
    case spotlight
    case screenshot

    // VoiceOver
    case voiceOverNext = "voice_over_next"
    case voiceOverPrevious = "voice_over_previous"
    case voiceOverActivate = "voice_over_activate"
    case voiceOverEscape = "voice_over_escape"

    // Editing
    case copy
    case paste
    case cut
    case undo
    case redo
    case selectAll = "select_all"
    case find

    /// HID Usage ID + modifier mask that produces this shortcut.
    public var keyEvent: (usage: UInt8, modifiers: KeyboardModifier) {
        switch self {
        // System
        case .home: (0x0B, .leftGUI) // Cmd-H
        case .appSwitcher: (0x2B, .leftGUI) // Cmd-Tab
        case .spotlight: (0x2C, .leftGUI) // Cmd-Space
        case .screenshot: (0x20, [.leftGUI, .leftShift]) // Cmd-Shift-3
        // VoiceOver
        case .voiceOverNext: (0x4F, [.leftControl, .leftAlt]) // Ctrl-Opt-Right
        case .voiceOverPrevious: (0x50, [.leftControl, .leftAlt]) // Ctrl-Opt-Left
        case .voiceOverActivate: (0x2C, [.leftControl, .leftAlt]) // Ctrl-Opt-Space
        case .voiceOverEscape: (0x29, [.leftControl, .leftAlt]) // Ctrl-Opt-Esc
        // Editing
        case .copy: (0x06, .leftGUI) // Cmd-C
        case .paste: (0x19, .leftGUI) // Cmd-V
        case .cut: (0x1B, .leftGUI) // Cmd-X
        case .undo: (0x1D, .leftGUI) // Cmd-Z
        case .redo: (0x1D, [.leftGUI, .leftShift]) // Cmd-Shift-Z
        case .selectAll: (0x04, .leftGUI) // Cmd-A
        case .find: (0x09, .leftGUI) // Cmd-F
        }
    }

    public var category: KeyboardCommandCategory {
        switch self {
        case .home, .appSwitcher, .spotlight, .screenshot:
            .system
        case .voiceOverNext, .voiceOverPrevious, .voiceOverActivate, .voiceOverEscape:
            .voiceOver
        case .copy, .paste, .cut, .undo, .redo, .selectAll, .find:
            .editing
        }
    }

    /// Short human-readable label, matching the action wording from
    /// Apple's reference page.
    public var displayName: String {
        switch self {
        case .home: "Go to Home Screen"
        case .appSwitcher: "Open App Switcher"
        case .spotlight: "Open Spotlight Search"
        case .screenshot: "Take Screenshot"
        case .voiceOverNext: "VoiceOver: next item"
        case .voiceOverPrevious: "VoiceOver: previous item"
        case .voiceOverActivate: "VoiceOver: activate selected item"
        case .voiceOverEscape: "VoiceOver: escape / back"
        case .copy: "Copy"
        case .paste: "Paste"
        case .cut: "Cut"
        case .undo: "Undo"
        case .redo: "Redo"
        case .selectAll: "Select All"
        case .find: "Find"
        }
    }

    /// Human-readable key combination, e.g. "Cmd-H" or "Ctrl-Opt-Right".
    public var shortcutDescription: String {
        let (usage, modifiers) = keyEvent
        var parts: [String] = []
        if modifiers.contains(.leftControl) || modifiers.contains(.rightControl) {
            parts.append("Ctrl")
        }
        if modifiers.contains(.leftAlt) || modifiers.contains(.rightAlt) {
            parts.append("Opt")
        }
        if modifiers.contains(.leftShift) || modifiers.contains(.rightShift) {
            parts.append("Shift")
        }
        if modifiers.contains(.leftGUI) {
            parts.append("Cmd")
        }
        parts.append(Self.usageLabel(usage))
        return parts.joined(separator: "-")
    }

    /// All shortcuts in a category, in declaration order.
    public static func shortcuts(in category: KeyboardCommandCategory) -> [KeyboardCommand] {
        allCases.filter { $0.category == category }
    }

    private static func usageLabel(_ usage: UInt8) -> String {
        switch usage {
        case 0x04 ... 0x1D:
            String(UnicodeScalar(UInt32(usage - 0x04) + 0x41)!) // A...Z
        case 0x1E ... 0x26:
            String(usage - 0x1D) // 1...9
        case 0x27: "0"
        case 0x28: "Return"
        case 0x29: "Esc"
        case 0x2A: "Delete"
        case 0x2B: "Tab"
        case 0x2C: "Space"
        case 0x4F: "Right"
        case 0x50: "Left"
        case 0x51: "Down"
        case 0x52: "Up"
        default: String(format: "0x%02X", usage)
        }
    }
}
