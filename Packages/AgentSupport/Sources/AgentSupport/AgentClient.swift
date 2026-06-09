//
//  AgentClient.swift
//  AgentSupport
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation

/// Provider-neutral LLM "chat completion with tools" abstraction.
///
/// Implementations map this protocol to a specific vendor API (Anthropic,
/// OpenAI, ...). The shape mirrors the Anthropic Messages API since tool-use
/// is first-class there, but is intentionally kept generic.
public protocol AgentClient: Sendable {
    func complete(
        system: String,
        messages: [AgentMessage],
        tools: [AgentTool],
        options: AgentCompletionOptions
    ) async throws -> AgentResponse
}

public enum AgentRole: String, Sendable, Hashable, Codable {
    case user
    case assistant
}

public enum AgentContent: Sendable, Hashable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseId: String, content: String, isError: Bool, image: ToolOutputImage?)
}

public struct AgentMessage: Sendable, Hashable {
    public var role: AgentRole
    public var content: [AgentContent]

    public init(role: AgentRole, content: [AgentContent]) {
        self.role = role
        self.content = content
    }
}

public struct AgentTool: Sendable, Hashable {
    public var name: String
    public var description: String
    public var inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct AgentCompletionOptions: Sendable, Hashable {
    public var model: String
    public var maxTokens: Int
    public var temperature: Double?

    public init(
        model: String,
        maxTokens: Int = 4096,
        temperature: Double? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

public enum AgentStopReason: Sendable, Hashable {
    case endTurn
    case toolUse
    case maxTokens
    case stopSequence
    case other(String)
}

public struct AgentResponse: Sendable, Hashable {
    public var content: [AgentContent]
    public var stopReason: AgentStopReason

    public init(content: [AgentContent], stopReason: AgentStopReason) {
        self.content = content
        self.stopReason = stopReason
    }
}

/// Sendable JSON value used for tool input schemas and tool inputs/outputs.
public enum JSONValue: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode JSONValue"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

public extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        default:
            nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value):
            value
        case .int(let value):
            Double(value)
        default:
            nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    subscript(_ key: String) -> JSONValue? {
        objectValue?[key]
    }
}
