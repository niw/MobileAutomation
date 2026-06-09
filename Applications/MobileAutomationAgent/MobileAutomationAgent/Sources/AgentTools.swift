//
//  AgentTools.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import ActionSupport
import AgentSupport
import Foundation
import MobileAutomationSupport

struct AgentToolDispatcher: ToolDispatcher {
    var client: Client
    var screenCapture: ScreenCapture
    var sourceSize: SourceSizeProvider
    var ledBlinker: LEDBlinker

    /// Delay after sending an action before taking the post-action screenshot,
    /// to give the UI time to react. 300 ms covers most visual transitions
    /// on iOS; tools that need longer pass `wait_ms` explicitly.
    var settleDelay: Duration = .milliseconds(300)

    func dispatch(name: String, input: JSONValue) async -> ToolOutput {
        switch name {
        case "screen_capture":
            let waitMs = input["wait_ms"]?.intValue ?? 0
            let settle: Duration = waitMs > 0 ? .milliseconds(waitMs) : settleDelay
            let capture = await screenCapture(settle)
            return result("captured", capture: capture)

        case "mouse_move_to":
            guard let x = input["x"]?.intValue, let y = input["y"]?.intValue else {
                return .error("missing `x` and `y`")
            }
            let size = await sourceSize()
            guard size.width > 0, size.height > 0 else {
                return .error("source size unavailable; start AirPlay mirroring first")
            }
            let max = Double(absoluteMouseLogicalMax)
            let lx = Int((Double(x) / Double(size.width) * max).rounded())
            let ly = Int((Double(y) / Double(size.height) * max).rounded())
            ledBlinker.advance()
            do {
                try client.moveAbsoluteMouse(x: lx, y: ly)
            } catch {
                return .error("\(error)")
            }
            let capture = await screenCapture(settleDelay)
            return result("moved to (\(x), \(y))", capture: capture)

        case "mouse_click":
            let raw = input["button"]?.stringValue ?? "left"
            let button: MouseButton
            switch raw {
            case "left": button = .left
            case "right": button = .right
            case "middle": button = .middle
            case "back": button = .back
            case "forward": button = .forward
            default: return .error("unknown button: \(raw)")
            }
            ledBlinker.advance()
            do {
                try client.absoluteMouseButton(button, pressed: true)
                try await Task.sleep(for: .milliseconds(30))
                try client.absoluteMouseButton(button, pressed: false)
            } catch {
                return .error("\(error)")
            }
            let capture = await screenCapture(settleDelay)
            return result("clicked \(raw)", capture: capture)

        case "mouse_scroll":
            let vertical = input["vertical"]?.intValue ?? 0
            let horizontal = input["horizontal"]?.intValue ?? 0
            ledBlinker.advance()
            do {
                try await client.scrollAbsoluteMouse(vertical: vertical, horizontal: horizontal)
            } catch {
                return .error("\(error)")
            }
            let capture = await screenCapture(settleDelay)
            return result("scrolled v=\(vertical) h=\(horizontal)", capture: capture)

        case "keyboard_tap_key":
            guard let usageValue = input["usage"]?.intValue,
                  (0 ... 255).contains(usageValue)
            else {
                return .error("missing or out-of-range `usage`")
            }
            let modifiers = parseModifiers(input["modifiers"])
            let usage = UInt8(usageValue)
            ledBlinker.advance()
            do {
                if !modifiers.isEmpty {
                    try client.setModifiers(modifiers)
                }
                try client.pressKey(usage: usage)
                try await Task.sleep(for: .milliseconds(30))
                try client.releaseKey(usage: usage)
                if !modifiers.isEmpty {
                    try client.setModifiers([])
                }
            } catch {
                return .error("\(error)")
            }
            let capture = await screenCapture(settleDelay)
            return result("key \(String(format: "0x%02X", usageValue)) pressed", capture: capture)

        case "keyboard_type_text":
            guard let text = input["text"]?.stringValue else {
                return .error("missing `text`")
            }
            ledBlinker.advance()
            do {
                try await client.type(text)
            } catch {
                return .error("\(error)")
            }
            let capture = await screenCapture(settleDelay)
            return result("typed \(text.count) chars", capture: capture)

        case "keyboard_send_shortcut":
            guard let raw = input["shortcut"]?.stringValue else {
                return .error("missing `shortcut`")
            }
            guard let shortcut = KeyboardCommand(rawValue: raw) else {
                return .error("unknown shortcut: \(raw)")
            }
            let (usage, modifiers) = shortcut.keyEvent
            ledBlinker.advance()
            do {
                if !modifiers.isEmpty {
                    try client.setModifiers(modifiers)
                }
                try client.pressKey(usage: usage)
                try await Task.sleep(for: .milliseconds(30))
                try client.releaseKey(usage: usage)
                if !modifiers.isEmpty {
                    try client.setModifiers([])
                }
            } catch {
                return .error("\(error)")
            }
            let capture = await screenCapture(settleDelay)
            return result("shortcut \(shortcut.rawValue) sent", capture: capture)

        default:
            return .error("unknown tool: \(name)")
        }
    }

    private func result(_ action: String, capture: AirPlayCapture?) -> ToolOutput {
        guard let capture else {
            return .ok("screen unavailable; \(action)")
        }
        let sw = Int(capture.sourceSize.width.rounded())
        let sh = Int(capture.sourceSize.height.rounded())
        let iw = Int(capture.imageSize.width.rounded())
        let ih = Int(capture.imageSize.height.rounded())
        let scaleString = AgentToolDispatcher.formatScale(capture.scale)
        let prefix = "screen \(sw)×\(sh), image \(iw)×\(ih) (scale \(scaleString))"
        print("[ScreenCapture] action=\(action) bytes=\(capture.pngData.count) hash=\(capture.pngData.hashValue)")
        let image = ToolOutputImage(data: capture.pngData, mediaType: "image/png")
        return .ok("\(prefix); \(action)", image: image)
    }

    private static func formatScale(_ scale: CGFloat) -> String {
        let rounded = (scale * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%g", rounded)
    }

    private func parseModifiers(_ input: JSONValue?) -> KeyboardModifier {
        guard let array = input?.arrayValue else {
            return []
        }
        var modifiers: KeyboardModifier = []
        for item in array {
            switch item.stringValue {
            case "ctrl":
                modifiers.insert(.leftControl)
            case "shift":
                modifiers.insert(.leftShift)
            case "alt", "option":
                modifiers.insert(.leftAlt)
            case "gui", "cmd", "command":
                modifiers.insert(.leftGUI)
            default:
                break
            }
        }
        return modifiers
    }
}
