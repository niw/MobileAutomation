//
//  LanguageModelAgentRunner.swift
//  AgentSupport
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import FoundationModels

/// `AgentRunner` backed by Apple's on-device `FoundationModels` framework.
///
/// Unlike HTTP providers, `LanguageModelSession` is stateful: it manages the
/// conversation transcript internally, and the tool-call loop happens
/// inside a single `session.respond(to:)` call (the framework calls our
/// `Tool` implementations as needed). This runner therefore does not loop
/// — it builds the session once, calls `respond` once, and surfaces tool
/// events from inside the tool closures.
///
/// The `done` tool is signalled by throwing a sentinel error inside the
/// tool's `call(arguments:)`, which interrupts `respond` and is caught
/// here to emit a `.finished` event.
public struct LanguageModelAgentRunner: AgentRunner {
    public var system: String
    public var tools: [AgentTool]
    public var options: LanguageModelAgentOptions
    public var maxSteps: Int

    public init(
        system: String,
        tools: [AgentTool],
        options: LanguageModelAgentOptions = .init(),
        maxSteps: Int = 30
    ) {
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
                await runOnce(
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

    private func runOnce(
        goal: String,
        dispatcher: any ToolDispatcher,
        continuation: AsyncStream<AgentEvent>.Continuation
    ) async {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            continuation.yield(.error("Foundation Model unavailable: \(Self.describe(reason))"))
            return
        }

        let state = LanguageModelLoopState(maxSteps: maxSteps)

        let fmTools: [any Tool]
        do {
            fmTools = try tools.map { agentTool in
                try DynamicAgentTool(
                    agentTool: agentTool,
                    dispatcher: dispatcher,
                    state: state,
                    continuation: continuation
                )
            }
        } catch {
            continuation.yield(.error("Failed to build tools: \(error)"))
            return
        }

        let session = LanguageModelSession(
            model: model,
            tools: fmTools,
            instructions: Instructions(system)
        )

        var generationOptions = GenerationOptions()
        if let temperature = options.temperature {
            generationOptions = GenerationOptions(temperature: temperature)
        }

        do {
            let response = try await session.respond(
                to: Prompt(goal),
                options: generationOptions
            )
            if !response.content.isEmpty {
                continuation.yield(.assistantText(response.content))
            }
            continuation.yield(
                .finished(reason: .endTurn, summary: nil, success: nil)
            )
        } catch let signal as LanguageModelDoneSignal {
            continuation.yield(
                .finished(reason: .endTurn, summary: signal.summary, success: signal.success)
            )
        } catch {
            // `LanguageModelSession.ToolCallError` wraps the error thrown
            // from `Tool.call`; unwrap to surface our sentinel.
            if let signal = Self.extractDoneSignal(from: error) {
                continuation.yield(
                    .finished(reason: .endTurn, summary: signal.summary, success: signal.success)
                )
                return
            }
            if let stepLimit = Self.extractStepLimit(from: error) {
                continuation.yield(.error(stepLimit))
                return
            }
            continuation.yield(.error("LLM call failed: \(error)"))
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "device does not support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is not enabled in Settings"
        case .modelNotReady:
            "model not ready (still downloading)"
        @unknown default:
            "unavailable"
        }
    }

    private static func extractDoneSignal(from error: any Error) -> LanguageModelDoneSignal? {
        if let signal = error as? LanguageModelDoneSignal {
            return signal
        }
        if let toolError = error as? LanguageModelSession.ToolCallError {
            return toolError.underlyingError as? LanguageModelDoneSignal
        }
        return nil
    }

    private static func extractStepLimit(from error: any Error) -> String? {
        if let limit = error as? LanguageModelStepLimitError {
            return "step limit reached (\(limit.maxSteps))"
        }
        if let toolError = error as? LanguageModelSession.ToolCallError,
           let limit = toolError.underlyingError as? LanguageModelStepLimitError
        {
            return "step limit reached (\(limit.maxSteps))"
        }
        return nil
    }
}

public struct LanguageModelAgentOptions: Sendable, Hashable {
    public var temperature: Double?

    public init(temperature: Double? = nil) {
        self.temperature = temperature
    }
}

/// Thrown from inside `DynamicAgentTool.call` when the model invokes `done`,
/// so that `session.respond(to:)` short-circuits instead of letting the
/// model keep going.
struct LanguageModelDoneSignal: Error {
    let summary: String
    let success: Bool
}

/// Thrown from inside `DynamicAgentTool.call` when the per-run tool-call
/// budget is exhausted.
struct LanguageModelStepLimitError: Error {
    let maxSteps: Int
}

/// Shared per-run state. Tracks tool-call count for the soft `maxSteps`
/// budget. `LanguageModelSession` may call tools concurrently, so this
/// has to be an actor.
actor LanguageModelLoopState {
    let maxSteps: Int
    private var stepCount: Int = 0

    init(maxSteps: Int) {
        self.maxSteps = maxSteps
    }

    /// Records one tool invocation. Returns the freshly-assigned step
    /// index, or `nil` if the budget is exhausted.
    func bumpStep() -> Int? {
        stepCount += 1
        if stepCount > maxSteps {
            return nil
        }
        return stepCount
    }
}

/// Generic `Tool` adapter: takes an `AgentTool` (name + description +
/// JSON-schema-shaped input schema) and exposes it to FoundationModels via
/// a dynamically-built `GenerationSchema`.
struct DynamicAgentTool: Tool {
    typealias Arguments = GeneratedContent
    typealias Output = String

    let name: String
    let description: String
    let parameters: GenerationSchema

    let dispatcher: any ToolDispatcher
    let state: LanguageModelLoopState
    let continuation: AsyncStream<AgentEvent>.Continuation

    init(
        agentTool: AgentTool,
        dispatcher: any ToolDispatcher,
        state: LanguageModelLoopState,
        continuation: AsyncStream<AgentEvent>.Continuation
    ) throws {
        name = agentTool.name
        description = agentTool.description
        self.dispatcher = dispatcher
        self.state = state
        self.continuation = continuation

        let root = try GenerationSchemaConverter.objectSchema(
            name: agentTool.name + "Arguments",
            description: agentTool.description,
            schema: agentTool.inputSchema
        )
        parameters = try GenerationSchema(root: root, dependencies: [])
    }

    func call(arguments: GeneratedContent) async throws -> String {
        guard let step = await state.bumpStep() else {
            throw LanguageModelStepLimitError(maxSteps: state.maxSteps)
        }
        let useId = "fm_\(step)"

        let json = GenerationSchemaConverter.toJSONValue(arguments)
        continuation.yield(.toolUse(id: useId, name: name, input: json))

        if name == agentDoneToolName {
            let summary = json["summary"]?.stringValue ?? ""
            let success = json["success"]?.boolValue ?? true
            continuation.yield(
                .toolResult(toolUseId: useId, name: name, output: .ok("acknowledged"))
            )
            throw LanguageModelDoneSignal(summary: summary, success: success)
        }

        let output = await dispatcher.dispatch(name: name, input: json)
        continuation.yield(.toolResult(toolUseId: useId, name: name, output: output))
        return output.content
    }
}

/// Converts between our provider-neutral `JSONValue` schemas / payloads and
/// FoundationModels' `DynamicGenerationSchema` / `GeneratedContent`.
enum GenerationSchemaConverter {
    enum ConversionError: Error {
        case notAnObjectSchema
        case missingPropertyType(String)
        case unsupportedType(String)
        case missingArrayItems
    }

    /// Build an object schema from a JSON-Schema-shaped `JSONValue`.
    /// Expected shape:
    ///   { "type": "object", "properties": { ... }, "required": [ ... ] }
    static func objectSchema(
        name: String,
        description: String?,
        schema: JSONValue
    ) throws -> DynamicGenerationSchema {
        guard schema["type"]?.stringValue == "object",
              let properties = schema["properties"]?.objectValue
        else {
            throw ConversionError.notAnObjectSchema
        }
        let required = Set((schema["required"]?.arrayValue ?? []).compactMap(\.stringValue))

        var props: [DynamicGenerationSchema.Property] = []
        for (key, propertySchema) in properties {
            let propertyName = "\(name)_\(key)"
            let propertyDescription = propertySchema["description"]?.stringValue
            let propertySubSchema = try valueSchema(
                name: propertyName,
                description: propertyDescription,
                value: propertySchema
            )
            props.append(
                DynamicGenerationSchema.Property(
                    name: key,
                    description: propertyDescription,
                    schema: propertySubSchema,
                    isOptional: !required.contains(key)
                )
            )
        }
        return DynamicGenerationSchema(
            name: name,
            description: description,
            properties: props
        )
    }

    /// Build a schema for a single property value.
    private static func valueSchema(
        name: String,
        description: String?,
        value: JSONValue
    ) throws -> DynamicGenerationSchema {
        guard let type = value["type"]?.stringValue else {
            throw ConversionError.missingPropertyType(name)
        }
        switch type {
        case "string":
            if let enumValues = value["enum"]?.arrayValue {
                let choices = enumValues.compactMap(\.stringValue)
                return DynamicGenerationSchema(
                    name: name,
                    description: description,
                    anyOf: choices
                )
            }
            return DynamicGenerationSchema(type: String.self)
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        case "array":
            guard let items = value["items"] else {
                throw ConversionError.missingArrayItems
            }
            let itemSchema = try valueSchema(
                name: "\(name)_item",
                description: nil,
                value: items
            )
            return DynamicGenerationSchema(arrayOf: itemSchema)
        case "object":
            return try objectSchema(name: name, description: description, schema: value)
        default:
            throw ConversionError.unsupportedType(type)
        }
    }

    /// Convert a `GeneratedContent` payload (the model's arguments to a
    /// tool call) back into our provider-neutral `JSONValue`.
    static func toJSONValue(_ content: GeneratedContent) -> JSONValue {
        switch content.kind {
        case .null:
            return .null
        case .bool(let value):
            return .bool(value)
        case .number(let value):
            if value.truncatingRemainder(dividingBy: 1) == 0,
               let intValue = Int(exactly: value)
            {
                return .int(intValue)
            }
            return .double(value)
        case .string(let value):
            return .string(value)
        case .array(let elements):
            return .array(elements.map(toJSONValue))
        case .structure(let properties, let orderedKeys):
            var dict: [String: JSONValue] = [:]
            for key in orderedKeys {
                if let value = properties[key] {
                    dict[key] = toJSONValue(value)
                }
            }
            return .object(dict)
        @unknown default:
            return .null
        }
    }
}
