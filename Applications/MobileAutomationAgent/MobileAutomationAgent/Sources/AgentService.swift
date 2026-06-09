//
//  AgentService.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import AgentSupport
import Foundation
import MobileAutomationSupport
import Observation
import UIKit

enum ConnectionState {
    case disconnected
    case connecting
    case connected(deviceName: String)
    case failed(message: String)
}

enum AgentRunState {
    case idle
    case running
    case finished(success: Bool, summary: String?)
    case failed(message: String)
}

enum TurnEntry: Identifiable {
    case userGoal(id: UInt64, text: String)
    case assistantText(id: UInt64, text: String)
    case toolUse(id: UInt64, useId: String, name: String, input: JSONValue)
    case toolResult(id: UInt64, useId: String, name: String, content: String, isError: Bool, image: UIImage?)
    case finished(id: UInt64, summary: String?, success: Bool?, stopReason: String)
    case error(id: UInt64, message: String)

    var id: UInt64 {
        switch self {
        case .userGoal(let id, _),
             .assistantText(let id, _),
             .toolUse(let id, _, _, _),
             .toolResult(let id, _, _, _, _, _),
             .finished(let id, _, _, _),
             .error(let id, _):
            id
        }
    }
}

typealias ScreenCapture = @Sendable (Duration) async -> AirPlayCapture?

typealias SourceSizeProvider = @Sendable () async -> CGSize

@MainActor
protocol AgentServiceProtocol: AnyObject, Observable {
    var connectionState: ConnectionState { get }
    var transcript: [TurnEntry] { get }
    var runState: AgentRunState { get }
    var goal: String { get set }
    var lastError: String? { get set }

    func connect()
    func disconnect()
    func clearTranscript()
    func startRun()
    func stopRun()
}

extension AgentServiceProtocol {
    var isConnected: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }

    var isRunning: Bool {
        if case .running = runState {
            return true
        }
        return false
    }
}

@MainActor
@Observable
final class AnyAgentService: AgentServiceProtocol {
    private let service: any AgentServiceProtocol

    init(_ service: some AgentServiceProtocol) {
        self.service = service
    }

    var connectionState: ConnectionState {
        service.connectionState
    }

    var transcript: [TurnEntry] {
        service.transcript
    }

    var runState: AgentRunState {
        service.runState
    }

    var goal: String {
        get {
            service.goal
        }
        set {
            service.goal = newValue
        }
    }

    var lastError: String? {
        get {
            service.lastError
        }
        set {
            service.lastError = newValue
        }
    }

    func connect() {
        service.connect()
    }

    func disconnect() {
        service.disconnect()
    }

    func clearTranscript() {
        service.clearTranscript()
    }

    func startRun() {
        service.startRun()
    }

    func stopRun() {
        service.stopRun()
    }
}

extension AgentServiceProtocol {
    func eraseToAnyAgentService() -> AnyAgentService {
        AnyAgentService(self)
    }
}

@MainActor
@Observable
final class AgentService: AgentServiceProtocol {
    var connectionState: ConnectionState = .disconnected
    var transcript: [TurnEntry] = []
    var runState: AgentRunState = .idle
    var lastError: String?

    private var _goal: String = Configuration.lastGoal

    var goal: String {
        get {
            _goal
        }
        set {
            _goal = newValue
            Configuration.lastGoal = newValue
        }
    }

    @ObservationIgnored
    private let screenCapture: ScreenCapture

    @ObservationIgnored
    private let sourceSize: SourceSizeProvider

    @ObservationIgnored
    private var client: Client?

    @ObservationIgnored
    private var runTask: Task<Void, Never>?

    @ObservationIgnored
    private var ledBlinker: LEDBlinker?

    @ObservationIgnored
    private var entryCounter: UInt64 = 0

    @ObservationIgnored
    private let liveActivity = LiveActivityManager()

    init(screenCapture: @escaping ScreenCapture, sourceSize: @escaping SourceSizeProvider) {
        self.screenCapture = screenCapture
        self.sourceSize = sourceSize
    }

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
            } catch {
                self.client = nil
                connectionState = .failed(message: "\(error)")
            }
        }
    }

    func disconnect() {
        stopRun()
        client = nil
        connectionState = .disconnected
    }

    func clearTranscript() {
        transcript.removeAll()
    }

    private func nextID() -> UInt64 {
        entryCounter &+= 1
        return entryCounter
    }

    func startRun() {
        if case .running = runState {
            return
        }
        guard case .connected = connectionState, let client else {
            lastError = "Not connected."
            return
        }
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else {
            lastError = "Goal is empty."
            return
        }

        let provider = Configuration.provider
        let profile = Configuration.promptProfile
        let systemPrompt = profile.systemPrompt
        let tools = profile.tools
        let runner: any AgentRunner
        switch provider {
        case .anthropic:
            guard let apiKey = try? AgentServiceKeyStore.read(for: .anthropic), !apiKey.isEmpty else {
                lastError = "Anthropic API key is not configured. Open Settings to add one."
                return
            }
            runner = RemoteAgentRunner(
                client: AnthropicClient(apiKey: apiKey),
                system: systemPrompt,
                tools: tools,
                options: AgentCompletionOptions(
                    model: Configuration.anthropicModel,
                    maxTokens: Configuration.agentMaxTokens
                ),
                maxSteps: Configuration.agentMaxSteps
            )
        case .openai:
            guard let apiKey = try? AgentServiceKeyStore.read(for: .openai), !apiKey.isEmpty else {
                lastError = "OpenAI API key is not configured. Open Settings to add one."
                return
            }
            runner = RemoteAgentRunner(
                client: OpenAIClient(apiKey: apiKey),
                system: systemPrompt,
                tools: tools,
                options: AgentCompletionOptions(
                    model: Configuration.openaiModel,
                    maxTokens: Configuration.agentMaxTokens
                ),
                maxSteps: Configuration.agentMaxSteps
            )
        case .foundationModel:
            runner = LanguageModelAgentRunner(
                system: systemPrompt,
                tools: tools,
                maxSteps: Configuration.agentMaxSteps
            )
        }

        transcript.append(.userGoal(id: nextID(), text: trimmedGoal))
        runState = .running

        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }
        liveActivity.start(goal: trimmedGoal)

        let blinker = LEDBlinker(client: client)
        ledBlinker = blinker
        let dispatcher = AgentToolDispatcher(
            client: client,
            screenCapture: screenCapture,
            sourceSize: sourceSize,
            ledBlinker: blinker
        )
        let events = runner.run(goal: trimmedGoal, dispatcher: dispatcher)

        runTask = Task { [weak self] in
            for await event in events {
                self?.handle(event: event)
            }
            self?.runTaskFinished()
        }
    }

    func stopRun() {
        runTask?.cancel()
        runTask = nil
        ledBlinker?.turnOff()
        ledBlinker = nil
        if case .running = runState {
            runState = .idle
            liveActivity.stop()
        }
    }

    private func handle(event: AgentEvent) {
        switch event {
        case .assistantText(let text):
            transcript.append(.assistantText(id: nextID(), text: text))
            liveActivity.update(statusText: "Thinking…", lastUpdate: text)
        case .toolUse(let useId, let name, let input):
            transcript.append(.toolUse(id: nextID(), useId: useId, name: name, input: input))
            liveActivity.update(statusText: name, lastUpdate: nil)
        case .toolResult(let useId, let name, let output):
            let image = output.image.flatMap { UIImage(data: $0.data) }
            transcript.append(
                .toolResult(
                    id: nextID(),
                    useId: useId,
                    name: name,
                    content: output.content,
                    isError: output.isError,
                    image: image
                )
            )
            let statusText = output.isError ? "\(name) ✗" : "\(name) →"
            liveActivity.update(statusText: statusText, lastUpdate: output.content)
        case .finished(let reason, let summary, let success):
            transcript.append(
                .finished(
                    id: nextID(),
                    summary: summary,
                    success: success,
                    stopReason: String(describing: reason)
                )
            )
            let successFlag = success ?? true
            runState = .finished(success: successFlag, summary: summary)
            Task {
                await NotificationManager.notifyFinished(success: successFlag, summary: summary)
            }
            liveActivity.finish(success: successFlag, summary: summary)
        case .error(let message):
            transcript.append(.error(id: nextID(), message: message))
            runState = .failed(message: message)
            Task {
                await NotificationManager.notifyError(message: message)
            }
            liveActivity.finish(success: false, summary: message)
        }
    }

    private func runTaskFinished() {
        runTask = nil
        ledBlinker?.turnOff()
        ledBlinker = nil
        if case .running = runState {
            runState = .idle
            Task {
                await NotificationManager.notifyStopped()
            }
            liveActivity.stop()
        }
    }
}

@MainActor
@Observable
final class PreviewAgentService: AgentServiceProtocol {
    var connectionState: ConnectionState
    var transcript: [TurnEntry]
    var runState: AgentRunState
    var goal: String
    var lastError: String?

    init(
        connectionState: ConnectionState = .disconnected,
        transcript: [TurnEntry] = [],
        runState: AgentRunState = .idle,
        goal: String = "",
        lastError: String? = nil
    ) {
        self.connectionState = connectionState
        self.transcript = transcript
        self.runState = runState
        self.goal = goal
        self.lastError = lastError
    }

    func connect() {
    }

    func disconnect() {
    }

    func clearTranscript() {
        transcript.removeAll()
    }

    func startRun() {
    }

    func stopRun() {
    }

    static var sampleTranscript: [TurnEntry] {
        [
            .userGoal(id: 1, text: "Open Settings and toggle Wi-Fi."),
            .assistantText(id: 2, text: "Cursor is near the centre. Moving to the Settings icon at (200, 800)."),
            .toolUse(
                id: 3, useId: "tu_1",
                name: "mouse_move",
                input: .object(["dx": .int(-440), "dy": .int(-590)])
            ),
            .toolResult(
                id: 4, useId: "tu_1",
                name: "mouse_move",
                content: "screen 1284×2778, image 642×1389 (scale 0.5); moved (-440, -590)",
                isError: false,
                image: nil
            ),
            .toolUse(
                id: 5, useId: "tu_2",
                name: "mouse_click",
                input: .object(["button": .string("left")])
            ),
            .toolResult(
                id: 6, useId: "tu_2",
                name: "mouse_click",
                content: "screen 1284×2778, image 642×1389 (scale 0.5); clicked left",
                isError: false,
                image: nil
            ),
            .finished(id: 7, summary: "Toggled Wi-Fi off.", success: true, stopReason: "endTurn"),
        ]
    }
}
