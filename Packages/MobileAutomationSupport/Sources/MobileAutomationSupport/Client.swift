//
//  Client.swift
//  MobileAutomationSupport
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import ActionSupport
import CoreMIDI
import Foundation
import Synchronization

public enum MouseButton: Sendable {
    case left
    case right
    case middle
    case back
    case forward

    /// MIDI Note number used to carry this button on both mouse channels.
    fileprivate var note: UInt8 {
        switch self {
        case .left:
            0
        case .right:
            1
        case .middle:
            2
        case .back:
            3
        case .forward:
            4
        }
    }
}

public enum LEDMode: Sendable {
    case off
    case on
    case blink
}

public enum ClientError: Error, Sendable {
    case clientCreateFailed(OSStatus)
    case outputPortCreateFailed(OSStatus)
    case inputPortCreateFailed(OSStatus)
    case destinationNotFound(String)
    case sourceNotFound(String)
    case sendFailed(OSStatus)
}

/// One screen-state update pushed by VoiceOver via the Pico's Braille HID
/// interface and forwarded over MIDI SysEx.
public struct BrailleUpdate: Sendable {
    public var timestamp: Date
    public var cells: [UInt8]

    public init(timestamp: Date, cells: [UInt8]) {
        self.timestamp = timestamp
        self.cells = cells
    }

    /// Unicode Braille pattern (U+2800–U+28FF) for each cell.
    public var brailleString: String {
        cells.map { String(Character(UnicodeScalar(0x2800 + UInt32($0))!)) }.joined()
    }

    /// Best-effort decoded characters using NABCC-style lookup with UEB
    /// capital / number sign handling. Cells outside the table fall back
    /// to the Unicode braille glyph (U+2800–U+28FF).
    public var charactersString: String {
        var result = ""
        var capitalNext = false
        var inNumber = false
        for cell in cells {
            // VoiceOver lays dots 7/8 on top of cells as focus / status
            // indicators; strip them before looking up the base letter.
            let base = cell & 0x3F
            // UEB capital sign (⠠)
            if base == 0x20 {
                capitalNext = true
                continue
            }
            // UEB number sign (⠼)
            if base == 0x3C {
                inNumber = true
                continue
            }
            var character: Character
            if inNumber, let digit = Self.uebDigits[base] {
                character = digit
            } else if let letter = Self.nabcc[base] {
                character = letter
                if Self.uebDigits[base] == nil {
                    inNumber = false
                }
            } else {
                character = Character(UnicodeScalar(0x2800 + UInt32(cell))!)
                inNumber = false
            }
            if capitalNext {
                character = Character(String(character).uppercased())
                capitalNext = false
            }
            result.append(character)
        }
        return result
    }

    private static let nabcc: [UInt8: Character] = [
        0x00: " ",
        0x01: "a", 0x03: "b", 0x09: "c", 0x19: "d", 0x11: "e",
        0x0B: "f", 0x1B: "g", 0x13: "h", 0x0A: "i", 0x1A: "j",
        0x05: "k", 0x07: "l", 0x0D: "m", 0x1D: "n", 0x15: "o",
        0x0F: "p", 0x1F: "q", 0x17: "r", 0x0E: "s", 0x1E: "t",
        0x25: "u", 0x27: "v", 0x3A: "w", 0x2D: "x", 0x3D: "y", 0x35: "z",
        0x02: ",", 0x06: ";", 0x12: ":", 0x28: ".",
        0x16: "!", 0x26: "?", 0x04: "'", 0x24: "-",
        0x3F: "=",
    ]

    private static let uebDigits: [UInt8: Character] = [
        0x01: "1", 0x03: "2", 0x09: "3", 0x19: "4", 0x11: "5",
        0x0B: "6", 0x1B: "7", 0x13: "8", 0x0A: "9", 0x1A: "0",
    ]
}

// MARK: - MIDI byte helpers

// MIDI status nibbles.
private let midiNoteOff: UInt8 = 0x80
private let midiNoteOn: UInt8 = 0x90
private let midiCC: UInt8 = 0xB0

// Channel assignments — must match Firmware/main.c.
private let chKeyboard: UInt8 = 0
private let chMouse: UInt8 = 1
private let chAbsoluteMouse: UInt8 = 2
private let chBraille: UInt8 = 3
private let chSystem: UInt8 = 15

// MIDI CC center value: deltas are encoded as `64 + signed`.
private let ccCenter: Int = 64

/// Logical maximum for absolute mouse X/Y. Matches `ABS_MOUSE_LOGICAL_MAX`
/// in Firmware/main.c. The two 7-bit MIDI CC bytes per axis carry a 14-bit
/// value, so the inclusive range is `0...16383`.
public let absoluteMouseLogicalMax: Int = 16383

/// Bidirectional connection to a Pico MIDI + HID Composite device.
///
/// Send side maps MIDI Note / CC into HID actions on the device. Receive
/// side decodes SysEx packets carrying Braille cell data and exposes them
/// through `brailleUpdates`.
public final class Client: Sendable {
    private let clientRef: MIDIClientRef
    private let outputPortRef: MIDIPortRef
    private let inputPortRef: MIDIPortRef
    private let destination: MIDIEndpointRef
    private let source: MIDIEndpointRef
    public let deviceName: String

    public let brailleUpdates: AsyncStream<BrailleUpdate>
    private let updatesContinuation: AsyncStream<BrailleUpdate>.Continuation

    public init(deviceNameContains matchingName: String = "pico") throws {
        var client = MIDIClientRef()
        let clientStatus = MIDIClientCreateWithBlock("Client" as CFString, &client, nil)
        guard clientStatus == noErr else {
            throw ClientError.clientCreateFailed(clientStatus)
        }

        var outputPort = MIDIPortRef()
        let outputPortStatus = MIDIOutputPortCreate(client, "out" as CFString, &outputPort)
        guard outputPortStatus == noErr else {
            throw ClientError.outputPortCreateFailed(outputPortStatus)
        }

        guard let destinationMatch = Self.findEndpoint(
            matching: matchingName,
            count: MIDIGetNumberOfDestinations(),
            at: MIDIGetDestination
        ) else {
            throw ClientError.destinationNotFound(matchingName)
        }

        guard let sourceMatch = Self.findEndpoint(
            matching: matchingName,
            count: MIDIGetNumberOfSources(),
            at: MIDIGetSource
        ) else {
            throw ClientError.sourceNotFound(matchingName)
        }

        let (stream, continuation) = AsyncStream<BrailleUpdate>.makeStream()
        let parser = MIDIStreamParser()

        var inputPort = MIDIPortRef()
        let inputPortStatus = MIDIInputPortCreateWithBlock(client, "in" as CFString, &inputPort) { packetListPointer, _ in
            let packetList = UnsafePointer<MIDIPacketList>(packetListPointer)
            var packet = packetList.pointee.packet
            for _ in 0 ..< packetList.pointee.numPackets {
                let length = Int(packet.length)
                let bytes = withUnsafeBytes(of: packet.data) { Array($0.prefix(length)) }
                let timestamp = Date()
                parser.feed(bytes) { message in
                    if let update = Client.decodeBrailleSysEx(message, timestamp: timestamp) {
                        continuation.yield(update)
                    }
                }
                packet = MIDIPacketNext(&packet).pointee
            }
        }
        guard inputPortStatus == noErr else {
            throw ClientError.inputPortCreateFailed(inputPortStatus)
        }
        MIDIPortConnectSource(inputPort, sourceMatch.endpoint, nil)

        clientRef = client
        outputPortRef = outputPort
        inputPortRef = inputPort
        destination = destinationMatch.endpoint
        source = sourceMatch.endpoint
        deviceName = destinationMatch.name
        brailleUpdates = stream
        updatesContinuation = continuation
    }

    deinit {
        updatesContinuation.finish()
        MIDIPortDisconnectSource(inputPortRef, source)
        MIDIPortDispose(inputPortRef)
        MIDIPortDispose(outputPortRef)
        MIDIClientDispose(clientRef)
    }

    private static func findEndpoint(
        matching matchingName: String,
        count: Int,
        at: (Int) -> MIDIEndpointRef
    ) -> (endpoint: MIDIEndpointRef, name: String)? {
        let matchingName = matchingName.lowercased()
        for index in 0 ..< count {
            let endpoint = at(index)
            if let name = displayName(of: endpoint),
               name.lowercased().contains(matchingName)
            {
                return (endpoint, name)
            }
        }
        return nil
    }

    private static func displayName(of endpoint: MIDIEndpointRef) -> String? {
        var nameRef: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &nameRef)
        return nameRef?.takeRetainedValue() as String?
    }

    private static func decodeBrailleSysEx(_ bytes: [UInt8], timestamp: Date) -> BrailleUpdate? {
        guard bytes.count >= 6,
              bytes[0] == 0xF0,
              bytes[1] == 0x7D,
              bytes[2] == 0x01
        else {
            return nil
        }
        let count = Int(bytes[3])
        let payloadEnd = 4 + count * 2
        guard bytes.count > payloadEnd, bytes[payloadEnd] == 0xF7 else {
            return nil
        }
        var cells: [UInt8] = []
        cells.reserveCapacity(count)
        for cellIndex in 0 ..< count {
            let lowNibble = bytes[4 + cellIndex * 2] & 0x0F
            let highNibble = bytes[4 + cellIndex * 2 + 1] & 0x0F
            cells.append((highNibble << 4) | lowNibble)
        }
        return BrailleUpdate(timestamp: timestamp, cells: cells)
    }

    // MARK: - Raw send

    private func sendBytes(_ bytes: [UInt8]) throws {
        var packetList = MIDIPacketList()
        let firstPacket = MIDIPacketListInit(&packetList)
        _ = bytes.withUnsafeBufferPointer { buffer in
            MIDIPacketListAdd(
                &packetList,
                MemoryLayout<MIDIPacketList>.size,
                firstPacket,
                0,
                buffer.count,
                buffer.baseAddress!
            )
        }
        let sendStatus = MIDISend(outputPortRef, destination, &packetList)
        guard sendStatus == noErr else {
            throw ClientError.sendFailed(sendStatus)
        }
    }

    // MARK: - Keyboard (channel 0)

    public func pressKey(usage: UInt8) throws {
        try sendBytes([midiNoteOn | chKeyboard, usage & 0x7F, 0x7F])
    }

    public func releaseKey(usage: UInt8) throws {
        try sendBytes([midiNoteOff | chKeyboard, usage & 0x7F, 0x00])
    }

    public func setModifiers(_ mask: KeyboardModifier) throws {
        try sendBytes([midiCC | chKeyboard, 0x01, mask.rawValue & 0x7F])
    }

    public func type(
        _ text: String,
        perKeyDelay: Duration = .milliseconds(60)
    ) async throws {
        for character in text {
            guard let event = Self.keyEvent(for: character) else {
                continue
            }
            if event.withShift {
                try setModifiers(.leftShift)
            }
            try pressKey(usage: event.usage)
            try await Task.sleep(for: perKeyDelay)
            try releaseKey(usage: event.usage)
            if event.withShift {
                try setModifiers([])
            }
            try await Task.sleep(for: perKeyDelay)
        }
    }

    private struct KeyEvent {
        var usage: UInt8
        var withShift: Bool
    }

    private static func keyEvent(for character: Character) -> KeyEvent? {
        guard character.isASCII, let scalar = character.unicodeScalars.first?.value else {
            return nil
        }
        switch scalar {
        case 0x61 ... 0x7A:
            return KeyEvent(usage: UInt8(scalar - 0x61) + 0x04, withShift: false)
        case 0x41 ... 0x5A:
            return KeyEvent(usage: UInt8(scalar - 0x41) + 0x04, withShift: true)
        default:
            break
        }
        switch character {
        case " ":
            return KeyEvent(usage: 0x2C, withShift: false)
        case "\n":
            return KeyEvent(usage: 0x28, withShift: false)
        case "\t":
            return KeyEvent(usage: 0x2B, withShift: false)
        default:
            return nil
        }
    }

    // MARK: - Mouse (channel 1)

    public func moveMouse(
        dx: Int,
        dy: Int,
        perStepDelay: Duration = .milliseconds(12)
    ) async throws {
        try await streamCCDelta(channel: chMouse, cc1: 0x01, value1: dx, cc2: 0x02, value2: dy, perStepDelay: perStepDelay)
    }

    public func scrollMouse(
        vertical: Int,
        horizontal: Int = 0,
        perStepDelay: Duration = .milliseconds(12)
    ) async throws {
        try await streamCCDelta(channel: chMouse, cc1: 0x03, value1: vertical, cc2: 0x04, value2: horizontal, perStepDelay: perStepDelay)
    }

    public func mouseButton(_ button: MouseButton, pressed: Bool) throws {
        let status: UInt8 = pressed ? (midiNoteOn | chMouse) : (midiNoteOff | chMouse)
        try sendBytes([status, button.note, pressed ? 0x7F : 0x00])
    }

    /// Issue two related CC streams on `channel`, splitting each into ±63
    /// chunks so the signed delta fits in a 7-bit `64+x` encoding.
    private func streamCCDelta(
        channel: UInt8,
        cc1: UInt8, value1: Int,
        cc2: UInt8, value2: Int,
        perStepDelay: Duration
    ) async throws {
        var r1 = value1
        var r2 = value2
        while r1 != 0 || r2 != 0 {
            let s1 = max(-63, min(63, r1))
            let s2 = max(-63, min(63, r2))
            if s1 != 0 {
                try sendBytes([midiCC | channel, cc1, UInt8(ccCenter + s1)])
            }
            if s2 != 0 {
                try sendBytes([midiCC | channel, cc2, UInt8(ccCenter + s2)])
            }
            r1 -= s1
            r2 -= s2
            if r1 != 0 || r2 != 0 {
                try await Task.sleep(for: perStepDelay)
            }
        }
    }

    // MARK: - Absolute Mouse (channel 2)

    /// Move the absolute-pointing-mouse HID interface to `(x, y)`. Both
    /// values are clamped to `0...absoluteMouseLogicalMax`. Pixel→logical
    /// scaling is the caller's responsibility — the host knows the screen
    /// dimensions, the firmware doesn't.
    public func moveAbsoluteMouse(x: Int, y: Int) throws {
        let clampedX = max(0, min(absoluteMouseLogicalMax, x))
        let clampedY = max(0, min(absoluteMouseLogicalMax, y))
        let xMSB = UInt8((clampedX >> 7) & 0x7F)
        let xLSB = UInt8(clampedX & 0x7F)
        let yMSB = UInt8((clampedY >> 7) & 0x7F)
        let yLSB = UInt8(clampedY & 0x7F)
        try sendBytes([midiCC | chAbsoluteMouse, 0x01, xMSB])
        try sendBytes([midiCC | chAbsoluteMouse, 0x02, xLSB])
        try sendBytes([midiCC | chAbsoluteMouse, 0x03, yMSB])
        try sendBytes([midiCC | chAbsoluteMouse, 0x04, yLSB])
    }

    /// Scroll the wheel (vertical) and pan (horizontal) as relative deltas on
    /// the absolute mouse channel, so scrolling works alongside absolute
    /// positioning without enabling the relative mouse interface.
    public func scrollAbsoluteMouse(
        vertical: Int,
        horizontal: Int = 0,
        perStepDelay: Duration = .milliseconds(12)
    ) async throws {
        try await streamCCDelta(channel: chAbsoluteMouse, cc1: 0x05, value1: vertical, cc2: 0x06, value2: horizontal, perStepDelay: perStepDelay)
    }

    public func absoluteMouseButton(_ button: MouseButton, pressed: Bool) throws {
        let status: UInt8 = pressed ? (midiNoteOn | chAbsoluteMouse) : (midiNoteOff | chAbsoluteMouse)
        try sendBytes([status, button.note, pressed ? 0x7F : 0x00])
    }

    // MARK: - Braille input (channel 3)

    /// Dot index is 1-based (1..8) to match HID Usage / Apple documentation.
    public func pressBrailleDot(_ dot: Int) throws {
        guard (1 ... 8).contains(dot) else {
            return
        }
        try sendBytes([midiNoteOn | chBraille, UInt8(dot - 1), 0x7F])
    }

    public func releaseBrailleDot(_ dot: Int) throws {
        guard (1 ... 8).contains(dot) else {
            return
        }
        try sendBytes([midiNoteOff | chBraille, UInt8(dot - 1), 0x00])
    }

    public func pressBrailleSpace() throws {
        try sendBytes([midiNoteOn | chBraille, 8, 0x7F])
    }

    public func releaseBrailleSpace() throws {
        try sendBytes([midiNoteOff | chBraille, 8, 0x00])
    }

    /// Routing key index is 0-based (0..39).
    public func pressRoutingKey(_ index: Int) throws {
        guard (0 ..< 40).contains(index) else {
            return
        }
        try sendBytes([midiNoteOn | chBraille, UInt8(16 + index), 0x7F])
    }

    public func releaseRoutingKey(_ index: Int) throws {
        guard (0 ..< 40).contains(index) else {
            return
        }
        try sendBytes([midiNoteOff | chBraille, UInt8(16 + index), 0x00])
    }

    /// Press `dots` (and optionally Space) together, hold, then release.
    /// VoiceOver / iOS Braille keyboard input commits on the release edge
    /// of the whole chord, so the brief hold matters.
    public func typeBrailleChord(
        dots: Set<Int>,
        includeSpace: Bool = false,
        holdDuration: Duration = .milliseconds(40)
    ) async throws {
        let sorted = dots.sorted()
        for dot in sorted {
            try pressBrailleDot(dot)
        }
        if includeSpace {
            try pressBrailleSpace()
        }
        try await Task.sleep(for: holdDuration)
        for dot in sorted {
            try releaseBrailleDot(dot)
        }
        if includeSpace {
            try releaseBrailleSpace()
        }
    }

    public func tapRoutingKey(
        _ index: Int,
        holdDuration: Duration = .milliseconds(40)
    ) async throws {
        try pressRoutingKey(index)
        try await Task.sleep(for: holdDuration)
        try releaseRoutingKey(index)
    }

    // MARK: - System (channel 15)

    public func setLED(_ mode: LEDMode) throws {
        let value: UInt8 = switch mode {
        case .off:
            0
        case .on:
            127
        case .blink:
            64
        }
        try sendBytes([midiCC | chSystem, 0x00, value])
    }
}

/// Buffers SysEx across MIDIPacket boundaries: CoreMIDI splits long SysEx
/// streams into multiple packets, so the F0..F7 envelope often spans more
/// than one callback invocation.
private final class MIDIStreamParser: Sendable {
    private struct State {
        var inSysEx = false
        var sysExBuf: [UInt8] = []
    }

    private let state = Mutex(State())

    func feed(_ bytes: [UInt8], yield: ([UInt8]) -> Void) {
        // Mutate the cross-packet buffer under the lock and only collect the
        // completed SysEx messages; yield them after unlocking so the caller's
        // closure never runs while the lock is held.
        let completed = state.withLock { state -> [[UInt8]] in
            var messages: [[UInt8]] = []
            var index = 0
            while index < bytes.count {
                if state.inSysEx {
                    while index < bytes.count {
                        state.sysExBuf.append(bytes[index])
                        if bytes[index] == 0xF7 {
                            messages.append(state.sysExBuf)
                            state.sysExBuf.removeAll(keepingCapacity: true)
                            state.inSysEx = false
                            index += 1
                            break
                        }
                        index += 1
                    }
                    continue
                }
                if bytes[index] == 0xF0 {
                    state.sysExBuf.removeAll(keepingCapacity: true)
                    state.sysExBuf.append(0xF0)
                    state.inSysEx = true
                    index += 1
                    continue
                }
                // Non-SysEx — skip the rest of this packet; we only care about
                // SysEx for the screen-read path.
                break
            }
            return messages
        }
        for message in completed {
            yield(message)
        }
    }
}
