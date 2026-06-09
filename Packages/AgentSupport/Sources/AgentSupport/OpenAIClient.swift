//
//  OpenAIClient.swift
//  AgentSupport
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation

public enum OpenAIClientError: Error, Sendable {
    case nonHTTPResponse
    case httpStatus(code: Int, body: String)
    case malformedFunctionArguments(String)
}

/// `AgentClient` implementation that talks to the OpenAI Responses API
/// (`POST /v1/responses`) over plain `URLSession`. Used through
/// `RemoteAgentRunner` exactly like `AnthropicClient`.
///
/// Responses API differs from the older Chat Completions API in two ways
/// that matter here:
/// - The conversation is sent as a flat list of "input items" rather than
///   role-tagged messages. Tool calls and tool results are siblings of
///   messages, not nested inside them.
/// - Function-call `arguments` are a JSON-encoded *string* in both
///   directions, not a nested JSON object.
public struct OpenAIClient: AgentClient {
    public var apiKey: String
    public var endpoint: URL
    public var urlSession: URLSession
    public var organization: String?

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        urlSession: URLSession = .shared,
        organization: String? = nil
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.urlSession = urlSession
        self.organization = organization
    }

    public func complete(
        system: String,
        messages: [AgentMessage],
        tools: [AgentTool],
        options: AgentCompletionOptions
    ) async throws -> AgentResponse {
        let body = RequestBody(
            model: options.model,
            input: messages.flatMap(Self.toInputItems),
            instructions: system.isEmpty ? nil : system,
            tools: tools.isEmpty ? nil : tools.map(Self.toAPITool),
            maxOutputTokens: options.maxTokens,
            temperature: options.temperature
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientError.nonHTTPResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIClientError.httpStatus(code: http.statusCode, body: text)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ResponseBody.self, from: data)
        return try Self.fromAPIResponse(decoded)
    }

    // MARK: - API mapping

    fileprivate struct RequestBody: Encodable {
        var model: String
        var input: [APIInputItem]
        var instructions: String?
        var tools: [APITool]?
        var maxOutputTokens: Int?
        var temperature: Double?

        enum CodingKeys: String, CodingKey {
            case model
            case input
            case instructions
            case tools
            case maxOutputTokens = "max_output_tokens"
            case temperature
        }
    }

    fileprivate struct APITool: Encodable {
        var type: String = "function"
        var name: String
        var description: String
        var parameters: JSONValue
    }

    fileprivate enum APIInputItem: Codable {
        case message(role: String, content: [APIContentBlock])
        case functionCall(callId: String, name: String, arguments: String)
        case functionCallOutput(callId: String, output: String)

        enum CodingKeys: String, CodingKey {
            case type
            case role
            case content
            case callId = "call_id"
            case name
            case arguments
            case output
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decodeIfPresent(String.self, forKey: .type)
            switch type {
            case "function_call":
                let callId = try container.decode(String.self, forKey: .callId)
                let name = try container.decode(String.self, forKey: .name)
                let arguments = try container.decode(String.self, forKey: .arguments)
                self = .functionCall(callId: callId, name: name, arguments: arguments)
            case "function_call_output":
                let callId = try container.decode(String.self, forKey: .callId)
                let output = try container.decode(String.self, forKey: .output)
                self = .functionCallOutput(callId: callId, output: output)
            default:
                let role = try container.decode(String.self, forKey: .role)
                let content = try container.decode([APIContentBlock].self, forKey: .content)
                self = .message(role: role, content: content)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .message(let role, let content):
                try container.encode("message", forKey: .type)
                try container.encode(role, forKey: .role)
                try container.encode(content, forKey: .content)
            case .functionCall(let callId, let name, let arguments):
                try container.encode("function_call", forKey: .type)
                try container.encode(callId, forKey: .callId)
                try container.encode(name, forKey: .name)
                try container.encode(arguments, forKey: .arguments)
            case .functionCallOutput(let callId, let output):
                try container.encode("function_call_output", forKey: .type)
                try container.encode(callId, forKey: .callId)
                try container.encode(output, forKey: .output)
            }
        }
    }

    fileprivate enum APIContentBlock: Codable {
        case inputText(String)
        case outputText(String)

        enum CodingKeys: String, CodingKey {
            case type
            case text
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            let text = try container.decode(String.self, forKey: .text)
            switch type {
            case "input_text":
                self = .inputText(text)
            case "output_text":
                self = .outputText(text)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown content block type: \(type)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .inputText(let text):
                try container.encode("input_text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .outputText(let text):
                try container.encode("output_text", forKey: .type)
                try container.encode(text, forKey: .text)
            }
        }
    }

    fileprivate struct ResponseBody: Decodable {
        var output: [APIOutputItem]
        var status: String?
        var incompleteDetails: IncompleteDetails?

        enum CodingKeys: String, CodingKey {
            case output
            case status
            case incompleteDetails = "incomplete_details"
        }
    }

    fileprivate struct IncompleteDetails: Decodable {
        var reason: String?
    }

    fileprivate enum APIOutputItem: Decodable {
        case message(id: String?, role: String, content: [APIContentBlock])
        case functionCall(id: String?, callId: String, name: String, arguments: String)
        case other

        enum CodingKeys: String, CodingKey {
            case type
            case id
            case role
            case content
            case callId = "call_id"
            case name
            case arguments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "message":
                let id = try container.decodeIfPresent(String.self, forKey: .id)
                let role = try container.decode(String.self, forKey: .role)
                let content = try container.decode([APIContentBlock].self, forKey: .content)
                self = .message(id: id, role: role, content: content)
            case "function_call":
                let id = try container.decodeIfPresent(String.self, forKey: .id)
                let callId = try container.decode(String.self, forKey: .callId)
                let name = try container.decode(String.self, forKey: .name)
                let arguments = try container.decode(String.self, forKey: .arguments)
                self = .functionCall(id: id, callId: callId, name: name, arguments: arguments)
            default:
                // Reasoning / refusal / unknown output items get skipped — we
                // only surface user-visible text and tool calls.
                self = .other
            }
        }
    }

    fileprivate static func toAPITool(_ tool: AgentTool) -> APITool {
        APITool(
            name: tool.name,
            description: tool.description,
            parameters: tool.inputSchema
        )
    }

    fileprivate static func toInputItems(_ message: AgentMessage) -> [APIInputItem] {
        var items: [APIInputItem] = []
        var textBlocks: [APIContentBlock] = []
        let roleString = message.role == .user ? "user" : "assistant"

        func flushText() {
            if !textBlocks.isEmpty {
                items.append(.message(role: roleString, content: textBlocks))
                textBlocks.removeAll()
            }
        }

        for block in message.content {
            switch block {
            case .text(let text):
                switch message.role {
                case .user:
                    textBlocks.append(.inputText(text))
                case .assistant:
                    textBlocks.append(.outputText(text))
                }
            case .toolUse(let id, let name, let input):
                flushText()
                items.append(
                    .functionCall(
                        callId: id,
                        name: name,
                        arguments: encodeArguments(input)
                    )
                )
            case .toolResult(let id, let content, _, _):
                // Responses API has no native image-in-tool-result; drop the
                // image for OpenAI for now. TODO: emit a follow-up user
                // message with an input_image block.
                flushText()
                items.append(.functionCallOutput(callId: id, output: content))
            }
        }
        flushText()
        return items
    }

    fileprivate static func encodeArguments(_ input: JSONValue) -> String {
        // The Responses API expects function-call arguments as a JSON-encoded
        // string. Fall back to an empty object so the round-trip stays valid.
        guard let data = try? JSONEncoder().encode(input),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    fileprivate static func decodeArguments(_ raw: String) throws -> JSONValue {
        guard let data = raw.data(using: .utf8) else {
            throw OpenAIClientError.malformedFunctionArguments(raw)
        }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    fileprivate static func fromAPIResponse(_ response: ResponseBody) throws -> AgentResponse {
        var content: [AgentContent] = []
        var hasFunctionCall = false

        for item in response.output {
            switch item {
            case .message(_, _, let blocks):
                for block in blocks {
                    if case .outputText(let text) = block {
                        content.append(.text(text))
                    }
                }
            case .functionCall(_, let callId, let name, let arguments):
                hasFunctionCall = true
                let input = (try? Self.decodeArguments(arguments)) ?? .object([:])
                content.append(.toolUse(id: callId, name: name, input: input))
            case .other:
                continue
            }
        }

        let stopReason: AgentStopReason = if response.incompleteDetails?.reason == "max_output_tokens" {
            .maxTokens
        } else if hasFunctionCall {
            .toolUse
        } else {
            .endTurn
        }

        return AgentResponse(content: content, stopReason: stopReason)
    }
}
