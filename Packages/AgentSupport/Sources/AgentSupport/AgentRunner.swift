//
//  AgentRunner.swift
//  AgentSupport
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation

public protocol ToolDispatcher: Sendable {
    func dispatch(name: String, input: JSONValue) async -> ToolOutput
}

public struct ToolOutputImage: Sendable, Hashable {
    public var data: Data
    public var mediaType: String

    public init(data: Data, mediaType: String = "image/png") {
        self.data = data
        self.mediaType = mediaType
    }
}

public struct ToolOutput: Sendable, Hashable {
    public var content: String
    public var isError: Bool
    public var image: ToolOutputImage?

    public init(content: String, isError: Bool = false, image: ToolOutputImage? = nil) {
        self.content = content
        self.isError = isError
        self.image = image
    }

    public static func ok(_ content: String, image: ToolOutputImage? = nil) -> ToolOutput {
        ToolOutput(content: content, isError: false, image: image)
    }

    public static func error(_ message: String) -> ToolOutput {
        ToolOutput(content: message, isError: true)
    }
}

public enum AgentEvent: Sendable {
    case assistantText(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseId: String, name: String, output: ToolOutput)
    case finished(reason: AgentStopReason, summary: String?, success: Bool?)
    case error(String)
}

/// Predefined tool name used to terminate the loop. Including this tool in
/// the `tools` array passed to the runner is optional — the runner intercepts
/// calls to it regardless.
public let agentDoneToolName = "done"

/// Provider-neutral runner that drives the `read → think → act → result` loop.
///
/// Two implementations are provided in this module:
/// - `RemoteAgentRunner` wraps an HTTP `AgentClient` (Anthropic Messages,
///   future OpenAI Responses, ...).
/// - `LanguageModelAgentRunner` uses Apple's on-device
///   `FoundationModels.LanguageModelSession`.
///
/// Implementations decide their own concurrency model — typically a detached
/// `Task` that feeds events into the returned `AsyncStream` and stops when the
/// stream is cancelled.
public protocol AgentRunner: Sendable {
    func run(
        goal: String,
        dispatcher: any ToolDispatcher
    ) -> AsyncStream<AgentEvent>
}

/// `AgentRunner` for HTTP-backed providers (Anthropic, OpenAI, ...).
///
/// Runs the canonical loop:
///   1. Call `client.complete` with the full message history.
///   2. For each `tool_use` block in the response, dispatch and append a
///      `tool_result`.
///   3. Repeat until the assistant ends the turn without tools, calls
///      `done`, or `maxSteps` is exhausted.
public struct RemoteAgentRunner: AgentRunner {
    public var client: any AgentClient
    public var system: String
    public var tools: [AgentTool]
    public var options: AgentCompletionOptions
    public var maxSteps: Int

    public init(
        client: any AgentClient,
        system: String,
        tools: [AgentTool],
        options: AgentCompletionOptions,
        maxSteps: Int = 30
    ) {
        self.client = client
        self.system = system
        self.tools = tools
        self.options = options
        self.maxSteps = maxSteps
    }

    public func run(
        goal: String,
        dispatcher: any ToolDispatcher
    ) -> AsyncStream<AgentEvent> {
        AsyncStream<AgentEvent> { continuation in
            let task = Task.detached {
                await runLoop(
                    goal: goal,
                    dispatcher: dispatcher,
                    continuation: continuation
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runLoop(
        goal: String,
        dispatcher: any ToolDispatcher,
        continuation: AsyncStream<AgentEvent>.Continuation
    ) async {
        var messages: [AgentMessage] = [
            AgentMessage(role: .user, content: [.text(goal)])
        ]

        for _ in 0 ..< maxSteps {
            if Task.isCancelled {
                continuation.yield(.error("cancelled"))
                return
            }

            let response: AgentResponse
            do {
                response = try await client.complete(
                    system: system,
                    messages: messages,
                    tools: tools,
                    options: options
                )
            } catch {
                continuation.yield(.error("LLM call failed: \(error)"))
                return
            }

            // Echo assistant content into the conversation history exactly as
            // received — the API requires this when feeding tool_results back.
            messages.append(AgentMessage(role: .assistant, content: response.content))

            var toolResults: [AgentContent] = []
            var doneInfo: (summary: String, success: Bool)?

            for block in response.content {
                switch block {
                case .text(let text):
                    if !text.isEmpty {
                        continuation.yield(.assistantText(text))
                    }
                case .toolUse(let id, let name, let input):
                    continuation.yield(.toolUse(id: id, name: name, input: input))

                    if name == agentDoneToolName {
                        let summary = input["summary"]?.stringValue ?? ""
                        let success = input["success"]?.boolValue ?? true
                        doneInfo = (summary, success)
                        // Emit a synthetic result so the UI can show closure,
                        // but skip feeding it back to the API since we're done.
                        continuation.yield(
                            .toolResult(
                                toolUseId: id,
                                name: name,
                                output: .ok("acknowledged")
                            )
                        )
                    } else {
                        let output = await dispatcher.dispatch(name: name, input: input)
                        continuation.yield(
                            .toolResult(toolUseId: id, name: name, output: output)
                        )
                        toolResults.append(
                            .toolResult(
                                toolUseId: id,
                                content: output.content,
                                isError: output.isError,
                                image: output.image
                            )
                        )
                    }
                case .toolResult:
                    // The assistant should not produce tool_result blocks.
                    continue
                }
            }

            if let doneInfo {
                continuation.yield(
                    .finished(
                        reason: .endTurn,
                        summary: doneInfo.summary,
                        success: doneInfo.success
                    )
                )
                return
            }

            if toolResults.isEmpty {
                // Model ended the turn without invoking tools.
                continuation.yield(
                    .finished(reason: response.stopReason, summary: nil, success: nil)
                )
                return
            }

            messages.append(AgentMessage(role: .user, content: toolResults))
        }

        continuation.yield(.error("step limit reached (\(maxSteps))"))
    }
}
