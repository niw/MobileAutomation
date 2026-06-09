//
//  Command.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import ActionSupport
import Foundation
import MobileAutomationSupport

enum CommandKind: String, CaseIterable, Identifiable {
    case tapKey
    case typeText
    case moveMouse
    case scrollMouse
    case click
    case moveAbsoluteMouse
    case scrollAbsoluteMouse
    case absoluteClick
    case typeBrailleChord
    case tapRoutingKey
    case setLED
    case wait

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .tapKey: "Tap Key"
        case .typeText: "Type Text"
        case .moveMouse: "Move Mouse"
        case .scrollMouse: "Scroll"
        case .click: "Click"
        case .moveAbsoluteMouse: "Move Absolute Mouse"
        case .scrollAbsoluteMouse: "Absolute Scroll"
        case .absoluteClick: "Absolute Click"
        case .typeBrailleChord: "Braille Chord"
        case .tapRoutingKey: "Tap Routing Key"
        case .setLED: "Set LED"
        case .wait: "Wait"
        }
    }

    var systemImage: String {
        switch self {
        case .tapKey: "keyboard"
        case .typeText: "text.cursor"
        case .moveMouse: "cursorarrow.motionlines"
        case .scrollMouse: "arrow.up.and.down"
        case .click: "cursorarrow.click"
        case .moveAbsoluteMouse: "scope"
        case .scrollAbsoluteMouse: "arrow.up.and.down.square"
        case .absoluteClick: "cursorarrow.click.2"
        case .typeBrailleChord: "circle.grid.2x2"
        case .tapRoutingKey: "hand.point.up.left"
        case .setLED: "lightbulb"
        case .wait: "clock"
        }
    }
}

struct Command: Identifiable {
    var id: UUID = .init()
    var kind: CommandKind

    // tapKey
    var keyUsage: UInt8 = 0x28 // Return
    var keyModifiers: KeyboardModifier = []

    // typeText
    var text: String = ""

    // moveMouse / scrollMouse / scrollAbsoluteMouse
    var dx: Int = 0
    var dy: Int = 0

    // moveAbsoluteMouse — logical coordinates 0...absoluteMouseLogicalMax
    var absX: Int = absoluteMouseLogicalMax / 2
    var absY: Int = absoluteMouseLogicalMax / 2

    // click
    var mouseButton: MouseButton = .left

    // typeBrailleChord
    var brailleDots: Set<Int> = []
    var brailleSpace: Bool = false

    // tapRoutingKey
    var routingIndex: Int = 0

    // setLED
    var ledMode: LEDMode = .on

    // wait
    var waitMilliseconds: Int = 200
}

extension Command {
    /// Short one-line summary for list rows / log entries.
    var summary: String {
        switch kind {
        case .tapKey:
            var parts: [String] = []
            if !keyModifiers.isEmpty {
                parts.append(keyModifiers.summary)
            }
            parts.append(String(format: "usage 0x%02X", keyUsage))
            return parts.joined(separator: " + ")
        case .typeText:
            let preview = text.prefix(40)
            return preview.isEmpty ? "(empty)" : "\"\(preview)\""
        case .moveMouse:
            return "dx \(dx), dy \(dy)"
        case .scrollMouse:
            return "v \(dy), h \(dx)"
        case .click:
            return mouseButton.displayName
        case .moveAbsoluteMouse:
            return "x \(absX), y \(absY)"
        case .scrollAbsoluteMouse:
            return "v \(dy), h \(dx)"
        case .absoluteClick:
            return mouseButton.displayName
        case .typeBrailleChord:
            let dots = brailleDots.sorted().map(String.init).joined(separator: ",")
            let dotsPart = dots.isEmpty ? "(none)" : dots
            return brailleSpace ? "\(dotsPart) + Space" : dotsPart
        case .tapRoutingKey:
            return "#\(routingIndex)"
        case .setLED:
            return ledMode.displayName
        case .wait:
            return "\(waitMilliseconds) ms"
        }
    }
}

extension MouseButton {
    var displayName: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .middle: "Middle"
        case .back: "Back"
        case .forward: "Forward"
        }
    }

    static let allCases: [MouseButton] = [.left, .right, .middle, .back, .forward]
}

extension LEDMode {
    var displayName: String {
        switch self {
        case .off: "Off"
        case .on: "On"
        case .blink: "Blink"
        }
    }

    static let allCases: [LEDMode] = [.off, .on, .blink]
}

extension KeyboardModifier {
    /// Comma-separated mnemonic list of set bits, e.g. "L-Ctrl, L-Alt".
    var summary: String {
        let labels: [(KeyboardModifier, String)] = [
            (.leftControl, "L-Ctrl"),
            (.leftShift, "L-Shift"),
            (.leftAlt, "L-Alt"),
            (.leftGUI, "L-GUI"),
            (.rightControl, "R-Ctrl"),
            (.rightShift, "R-Shift"),
            (.rightAlt, "R-Alt"),
        ]
        return labels
            .filter { contains($0.0) }
            .map(\.1)
            .joined(separator: ", ")
    }
}
