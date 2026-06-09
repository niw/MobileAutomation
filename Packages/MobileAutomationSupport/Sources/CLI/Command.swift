//
//  Command.swift
//  MobileAutomationSupportCLI
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import ActionSupport
import ArgumentParser
import Foundation
import MobileAutomationSupport

@main
struct Command: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "midi-Client",
        abstract: "Control a Pico MIDI Braille Display over CoreMIDI.",
        subcommands: [
            TypeText.self,
            Key.self,
            Press.self,
            Release.self,
            Modifier.self,
            Mouse.self,
            Scroll.self,
            Click.self,
            AbsoluteMouse.self,
            AbsoluteScroll.self,
            AbsoluteClick.self,
            LED.self,
            Braille.self,
            BrailleChord.self,
            BrailleRouting.self,
        ]
    )
}

private func makeClient() throws -> Client {
    let client = try Client()
    FileHandle.standardError.write(Data("→ \(client.deviceName)\n".utf8))
    return client
}

private func parseHex(_ s: String) throws -> UInt8 {
    var str = s
    if str.hasPrefix("0x") || str.hasPrefix("0X") {
        str = String(str.dropFirst(2))
    }
    guard let value = UInt8(str, radix: 16) else {
        throw ValidationError("Invalid hex value: \(s)")
    }
    return value
}

extension Command {
    struct TypeText: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "type",
            abstract: "Type ASCII text (a-z, A-Z, space, tab, newline)."
        )

        @Argument(help: "Text to type. Multiple arguments are joined with a space.")
        var text: [String] = []

        func run() async throws {
            let Client = try makeClient()
            try await Client.type(text.joined(separator: " "))
        }
    }

    struct Key: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Press and release a HID Usage ID (e.g. 28 = Enter, 29 = ESC)."
        )

        @Argument(help: "HID Usage ID in hex.", transform: parseHex)
        var usage: UInt8

        func run() async throws {
            let Client = try makeClient()
            try Client.pressKey(usage: usage)
            try await Task.sleep(for: .milliseconds(30))
            try Client.releaseKey(usage: usage)
        }
    }

    struct Press: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Press a HID key without releasing."
        )

        @Argument(help: "HID Usage ID in hex.", transform: parseHex)
        var usage: UInt8

        func run() async throws {
            let Client = try makeClient()
            try Client.pressKey(usage: usage)
        }
    }

    struct Release: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Release a HID key."
        )

        @Argument(help: "HID Usage ID in hex.", transform: parseHex)
        var usage: UInt8

        func run() async throws {
            let Client = try makeClient()
            try Client.releaseKey(usage: usage)
        }
    }

    struct Modifier: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set keyboard modifier bitmask (LCtrl 0x01, LShift 0x02, LAlt 0x04, LGUI 0x08, RCtrl 0x10, RShift 0x20, RAlt 0x40)."
        )

        @Argument(help: "Modifier bitmask in hex.", transform: parseHex)
        var mask: UInt8

        func run() async throws {
            let Client = try makeClient()
            try Client.setModifiers(KeyboardModifier(rawValue: mask))
        }
    }

    struct Mouse: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Relative mouse move."
        )

        @Argument(help: "Delta X.")
        var dx: Int

        @Argument(help: "Delta Y.")
        var dy: Int

        func run() async throws {
            let Client = try makeClient()
            try await Client.moveMouse(dx: dx, dy: dy)
        }
    }

    struct AbsoluteMouse: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "absolute-mouse",
            abstract: "Move the absolute-positioning mouse to (x, y). Range 0...\(absoluteMouseLogicalMax)."
        )

        @Argument(help: "Absolute X (0...\(absoluteMouseLogicalMax)).")
        var x: Int

        @Argument(help: "Absolute Y (0...\(absoluteMouseLogicalMax)).")
        var y: Int

        func run() async throws {
            let Client = try makeClient()
            try Client.moveAbsoluteMouse(x: x, y: y)
        }
    }

    struct Click: AsyncParsableCommand {
        enum Button: String, ExpressibleByArgument {
            case left
            case right
            case middle
            case back
            case forward

            var asMouseButton: MouseButton {
                switch self {
                case .left: .left
                case .right: .right
                case .middle: .middle
                case .back: .back
                case .forward: .forward
                }
            }
        }

        static let configuration = CommandConfiguration(
            abstract: "Click a mouse button once."
        )

        @Argument(help: "Which button.")
        var button: Button = .left

        func run() async throws {
            let Client = try makeClient()
            try Client.mouseButton(button.asMouseButton, pressed: true)
            try await Task.sleep(for: .milliseconds(30))
            try Client.mouseButton(button.asMouseButton, pressed: false)
        }
    }

    struct Scroll: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scroll the relative mouse wheel / pan."
        )

        @Argument(help: "Vertical scroll amount (positive = up).")
        var vertical: Int

        @Argument(help: "Horizontal scroll amount (positive = right).")
        var horizontal: Int = 0

        func run() async throws {
            let Client = try makeClient()
            try await Client.scrollMouse(vertical: vertical, horizontal: horizontal)
        }
    }

    struct AbsoluteScroll: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "absolute-scroll",
            abstract: "Scroll the absolute mouse wheel / pan."
        )

        @Argument(help: "Vertical scroll amount (positive = up).")
        var vertical: Int

        @Argument(help: "Horizontal scroll amount (positive = right).")
        var horizontal: Int = 0

        func run() async throws {
            let Client = try makeClient()
            try await Client.scrollAbsoluteMouse(vertical: vertical, horizontal: horizontal)
        }
    }

    struct AbsoluteClick: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "absolute-click",
            abstract: "Click an absolute mouse button once."
        )

        @Argument(help: "Which button.")
        var button: Click.Button = .left

        func run() async throws {
            let Client = try makeClient()
            try Client.absoluteMouseButton(button.asMouseButton, pressed: true)
            try await Task.sleep(for: .milliseconds(30))
            try Client.absoluteMouseButton(button.asMouseButton, pressed: false)
        }
    }

    struct LED: AsyncParsableCommand {
        enum Mode: String, ExpressibleByArgument {
            case off
            case on
            case blink

            var asLEDMode: LEDMode {
                switch self {
                case .off: .off
                case .on: .on
                case .blink: .blink
                }
            }
        }

        static let configuration = CommandConfiguration(
            commandName: "led",
            abstract: "Control the on-board LED."
        )

        @Argument(help: "LED mode.")
        var mode: Mode = .blink

        func run() async throws {
            let Client = try makeClient()
            try Client.setLED(mode.asLEDMode)
        }
    }

    struct Braille: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Stream Braille screen-state updates (Ctrl-C to stop)."
        )

        func run() async throws {
            let Client = try makeClient()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            for await update in Client.brailleUpdates {
                let ts = formatter.string(from: update.timestamp)
                print("\(ts)  \(update.brailleString)  \"\(update.charactersString)\"")
            }
        }
    }

    struct BrailleChord: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "braille-chord",
            abstract: "Press a Braille dot chord (dots 1-8), optionally with Space, then release. Example: 'braille-chord 1 4' types 'c' in computer braille."
        )

        @Argument(help: "Dot indices to press simultaneously (1-8). May be repeated.")
        var dots: [Int] = []

        @Flag(name: .long, help: "Include Space in the chord (for VoiceOver commands).")
        var space: Bool = false

        func run() async throws {
            let Client = try makeClient()
            try await Client.typeBrailleChord(
                dots: Set(dots),
                includeSpace: space
            )
        }
    }

    struct BrailleRouting: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "braille-routing",
            abstract: "Tap a Braille cursor routing key (0-39)."
        )

        @Argument(help: "Routing key index (0-39, left-to-right cell position).")
        var index: Int

        func run() async throws {
            let Client = try makeClient()
            try await Client.tapRoutingKey(index)
        }
    }
}
