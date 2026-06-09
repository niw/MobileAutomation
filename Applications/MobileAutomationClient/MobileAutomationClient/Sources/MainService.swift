//
//  MainService.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import MobileAutomationSupport
import Observation

enum ConnectionState {
    case disconnected
    case connecting
    case connected(deviceName: String)
    case failed(message: String)
}

@MainActor
protocol MainServiceProtocol: AnyObject, Observable {
    var connectionState: ConnectionState { get }
    var commands: [Command] { get }
    var logEntries: [LogEntry] { get }
    var isRunning: Bool { get }
    var lastError: String? { get set }

    func connect()
    func disconnect()

    func addCommand(_ command: Command)
    func updateCommand(_ command: Command)
    func deleteCommands(at offsets: IndexSet)
    func moveCommands(from source: IndexSet, to destination: Int)

    func runCommands()
    func cancelRun()
    func clearLog()
}

extension MainServiceProtocol {
    var isConnected: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }

    func command(id: Command.ID) -> Command? {
        commands.first { $0.id == id }
    }
}

@MainActor
@Observable
final class AnyMainService: MainServiceProtocol {
    private let mainService: any MainServiceProtocol

    init(_ mainService: some MainServiceProtocol) {
        self.mainService = mainService
    }

    var connectionState: ConnectionState {
        mainService.connectionState
    }

    var commands: [Command] {
        mainService.commands
    }

    var logEntries: [LogEntry] {
        mainService.logEntries
    }

    var isRunning: Bool {
        mainService.isRunning
    }

    var lastError: String? {
        get { mainService.lastError }
        set { mainService.lastError = newValue }
    }

    func connect() {
        mainService.connect()
    }

    func disconnect() {
        mainService.disconnect()
    }

    func addCommand(_ command: Command) {
        mainService.addCommand(command)
    }

    func updateCommand(_ command: Command) {
        mainService.updateCommand(command)
    }

    func deleteCommands(at offsets: IndexSet) {
        mainService.deleteCommands(at: offsets)
    }

    func moveCommands(from source: IndexSet, to destination: Int) {
        mainService.moveCommands(from: source, to: destination)
    }

    func runCommands() {
        mainService.runCommands()
    }

    func cancelRun() {
        mainService.cancelRun()
    }

    func clearLog() {
        mainService.clearLog()
    }
}

extension MainServiceProtocol {
    func eraseToAnyMainService() -> AnyMainService {
        AnyMainService(self)
    }
}

@MainActor
@Observable
final class MainService: MainServiceProtocol {
    var connectionState: ConnectionState = .disconnected
    var commands: [Command] = []
    var logEntries: [LogEntry] = []
    var isRunning: Bool = false
    var lastError: String?

    private static let maxLogEntries = 500

    @ObservationIgnored
    private var client: Client?

    @ObservationIgnored
    private var receiveTask: Task<Void, Never>?

    @ObservationIgnored
    private var runTask: Task<Void, Never>?

    @ObservationIgnored
    private var logCounter: UInt64 = 0

    // MARK: - Connection

    func connect() {
        switch connectionState {
        case .connecting, .connected:
            return
        case .disconnected, .failed:
            break
        }
        connectionState = .connecting
        Task {
            do {
                let client = try Client()
                self.client = client
                connectionState = .connected(deviceName: client.deviceName)
                appendLog(.info, title: "Connected", detail: client.deviceName)
                startReceiving(from: client)
            } catch {
                self.client = nil
                let message = "\(error)"
                connectionState = .failed(message: message)
                appendLog(.error, title: "Connect failed", detail: message)
            }
        }
    }

    func disconnect() {
        cancelRun()
        receiveTask?.cancel()
        receiveTask = nil
        client = nil
        connectionState = .disconnected
        appendLog(.info, title: "Disconnected", detail: nil)
    }

    private func startReceiving(from client: Client) {
        receiveTask?.cancel()
        let stream = client.brailleUpdates
        receiveTask = Task { [weak self] in
            for await update in stream {
                self?.appendLog(
                    .received,
                    title: "Braille \(update.brailleString)",
                    detail: "Text: \(update.charactersString)"
                )
            }
        }
    }

    // MARK: - Script editing

    func addCommand(_ command: Command) {
        commands.append(command)
    }

    func updateCommand(_ command: Command) {
        guard let index = commands.firstIndex(where: { $0.id == command.id }) else {
            return
        }
        commands[index] = command
    }

    func deleteCommands(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
    }

    func moveCommands(from source: IndexSet, to destination: Int) {
        commands.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Run / cancel

    func runCommands() {
        guard !isRunning else {
            return
        }
        guard !commands.isEmpty else {
            return
        }
        guard let client else {
            lastError = "Not connected."
            appendLog(.error, title: "Run aborted", detail: "Not connected.")
            return
        }
        let script = commands
        isRunning = true
        appendLog(.info, title: "Run started", detail: "\(script.count) command(s)")
        runTask = Task { [weak self] in
            for (index, command) in script.enumerated() {
                if Task.isCancelled {
                    break
                }
                guard let self else {
                    return
                }
                appendLog(
                    .sent,
                    title: "[\(index + 1)] \(command.kind.displayName)",
                    detail: command.summary
                )
                do {
                    try await execute(command, with: client)
                } catch {
                    appendLog(
                        .error,
                        title: "Command failed",
                        detail: "\(error)"
                    )
                    break
                }
            }
            guard let self else {
                return
            }
            isRunning = false
            runTask = nil
            appendLog(
                .info,
                title: Task.isCancelled ? "Run cancelled" : "Run finished",
                detail: nil
            )
        }
    }

    func cancelRun() {
        runTask?.cancel()
    }

    func clearLog() {
        logEntries.removeAll()
    }

    // MARK: - Internals

    private func appendLog(
        _ direction: LogEntry.Direction,
        title: String,
        detail: String?
    ) {
        logCounter &+= 1
        logEntries.append(
            LogEntry(
                id: logCounter,
                timestamp: Date(),
                direction: direction,
                title: title,
                detail: detail
            )
        )
        if logEntries.count > Self.maxLogEntries {
            logEntries.removeFirst(logEntries.count - Self.maxLogEntries)
        }
    }

    private func execute(_ command: Command, with client: Client) async throws {
        switch command.kind {
        case .tapKey:
            if !command.keyModifiers.isEmpty {
                try client.setModifiers(command.keyModifiers)
            }
            try client.pressKey(usage: command.keyUsage)
            try await Task.sleep(for: .milliseconds(30))
            try client.releaseKey(usage: command.keyUsage)
            if !command.keyModifiers.isEmpty {
                try client.setModifiers([])
            }
        case .typeText:
            try await client.type(command.text)
        case .moveMouse:
            try await client.moveMouse(dx: command.dx, dy: command.dy)
        case .scrollMouse:
            try await client.scrollMouse(vertical: command.dy, horizontal: command.dx)
        case .click:
            try client.mouseButton(command.mouseButton, pressed: true)
            try await Task.sleep(for: .milliseconds(30))
            try client.mouseButton(command.mouseButton, pressed: false)
        case .moveAbsoluteMouse:
            try client.moveAbsoluteMouse(x: command.absX, y: command.absY)
        case .scrollAbsoluteMouse:
            try await client.scrollAbsoluteMouse(vertical: command.dy, horizontal: command.dx)
        case .absoluteClick:
            try client.absoluteMouseButton(command.mouseButton, pressed: true)
            try await Task.sleep(for: .milliseconds(30))
            try client.absoluteMouseButton(command.mouseButton, pressed: false)
        case .typeBrailleChord:
            try await client.typeBrailleChord(
                dots: command.brailleDots,
                includeSpace: command.brailleSpace
            )
        case .tapRoutingKey:
            try await client.tapRoutingKey(command.routingIndex)
        case .setLED:
            try client.setLED(command.ledMode)
        case .wait:
            try await Task.sleep(for: .milliseconds(command.waitMilliseconds))
        }
    }
}

@MainActor
@Observable
final class PreviewMainService: MainServiceProtocol {
    var connectionState: ConnectionState
    var commands: [Command]
    var logEntries: [LogEntry]
    var isRunning: Bool
    var lastError: String?

    init(
        connectionState: ConnectionState = .disconnected,
        commands: [Command] = [],
        logEntries: [LogEntry] = [],
        isRunning: Bool = false,
        lastError: String? = nil
    ) {
        self.connectionState = connectionState
        self.commands = commands
        self.logEntries = logEntries
        self.isRunning = isRunning
        self.lastError = lastError
    }

    func connect() {
    }

    func disconnect() {
    }

    func addCommand(_ command: Command) {
        commands.append(command)
    }

    func updateCommand(_ command: Command) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
        }
    }

    func deleteCommands(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
    }

    func moveCommands(from source: IndexSet, to destination: Int) {
        commands.move(fromOffsets: source, toOffset: destination)
    }

    func runCommands() {
    }

    func cancelRun() {
    }

    func clearLog() {
        logEntries.removeAll()
    }

    static var sampleCommands: [Command] {
        [
            Command(kind: .tapKey, keyUsage: 0x0B, keyModifiers: .leftGUI),
            Command(kind: .wait, waitMilliseconds: 300),
            Command(kind: .typeText, text: "hello"),
            Command(kind: .typeBrailleChord, brailleDots: [1, 2, 5], brailleSpace: true),
            Command(kind: .moveMouse, dx: 30, dy: 0),
            Command(kind: .click, mouseButton: .left),
        ]
    }

    static var sampleLog: [LogEntry] {
        let base = Date(timeIntervalSinceNow: -10)
        return [
            LogEntry(id: 1, timestamp: base, direction: .info, title: "Connected", detail: "Pico MIDI HID Composite"),
            LogEntry(id: 2, timestamp: base.addingTimeInterval(1.0), direction: .sent, title: "[1] Tap Key", detail: "L-GUI + usage 0x0B"),
            LogEntry(id: 3, timestamp: base.addingTimeInterval(1.3), direction: .received, title: "Braille ⠠⠓⠑⠇⠇⠕", detail: "ASCII: Hello"),
            LogEntry(id: 4, timestamp: base.addingTimeInterval(1.5), direction: .sent, title: "[2] Wait", detail: "300 ms"),
            LogEntry(id: 5, timestamp: base.addingTimeInterval(2.0), direction: .sent, title: "[3] Type Text", detail: "\"hello\""),
            LogEntry(id: 6, timestamp: base.addingTimeInterval(2.8), direction: .error, title: "Command failed", detail: "ClientError.sendFailed(-50)"),
        ]
    }
}
