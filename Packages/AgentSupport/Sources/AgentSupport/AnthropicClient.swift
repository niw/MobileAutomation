//
//  AnthropicClient.swift
//  AgentSupport
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation

public enum AnthropicClientError: Error, Sendable {
    case nonHTTPResponse
    case httpStatus(code: Int, body: String)
}

/// `AgentClient` implementation that talks to the Anthropic Messages API
/// over plain `URLSession`. No third-party SDK dependency.
public struct AnthropicClient: AgentClient {
    public var apiKey: String
    public var endpoint: URL
    public var urlSession: URLSession
    public var anthropicVersion: String

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        urlSession: URLSession = .shared,
        anthropicVersion: String = "2023-06-01"
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.urlSession = urlSession
        self.anthropicVersion = anthropicVersion
    }

    public func complete(
        system: String,
        messages: [AgentMessage],
        tools: [AgentTool],
        options: AgentCompletionOptions
    ) async throws -> AgentResponse {
        let body = RequestBody(
            model: options.model,
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            system: system.isEmpty ? nil : system,
            tools: tools.isEmpty ? nil : tools.map(Self.toAPITool),
            messages: messages.map(Self.toAPIMessage)
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicClientError.nonHTTPResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicClientError.httpStatus(code: http.statusCode, body: text)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ResponseBody.self, from: data)
        return Self.fromAPIResponse(decoded)
    }

    // MARK: - API mapping

    fileprivate struct RequestBody: Encodable {
        var model: String
        var maxTokens: Int
        var temperature: Double?
        var system: String?
        var tools: [APITool]?
        var messages: [APIMessage]

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case temperature
            case system
            case tools
            case messages
        }
    }

    fileprivate struct APITool: Encodable {
        var name: String
        var description: String
        var inputSchema: JSONValue

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case inputSchema = "input_schema"
        }
    }

    fileprivate struct APIMessage: Codable {
        var role: String
        var content: [APIContentBlock]
    }

    fileprivate enum APIContentBlock: Codable {
        case text(String)
        case toolUse(id: String, name: String, input: JSONValue)
        case toolResult(toolUseId: String, content: [APIToolResultContent], isError: Bool?)

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case id
            case name
            case input
            case toolUseId = "tool_use_id"
            case content
            case isError = "is_error"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case "tool_use":
                let id = try container.decode(String.self, forKey: .id)
                let name = try container.decode(String.self, forKey: .name)
                let input = try container.decode(JSONValue.self, forKey: .input)
                self = .toolUse(id: id, name: name, input: input)
            case "tool_result":
                let id = try container.decode(String.self, forKey: .toolUseId)
                // Anthropic accepts both a raw string and an array of typed
                // content blocks. Round-trip both.
                let content: [APIToolResultContent] = if let text = try? container.decode(String.self, forKey: .content) {
                    [.text(text)]
                } else {
                    try container.decode([APIToolResultContent].self, forKey: .content)
                }
                let isError = try container.decodeIfPresent(Bool.self, forKey: .isError)
                self = .toolResult(toolUseId: id, content: content, isError: isError)
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
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .toolUse(let id, let name, let input):
                try container.encode("tool_use", forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(input, forKey: .input)
            case .toolResult(let toolUseId, let content, let isError):
                try container.encode("tool_result", forKey: .type)
                try container.encode(toolUseId, forKey: .toolUseId)
                try container.encode(content, forKey: .content)
                if let isError {
                    try container.encode(isError, forKey: .isError)
                }
            }
        }
    }

    fileprivate enum APIToolResultContent: Codable {
        case text(String)
        case image(mediaType: String, base64: String)

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case source
        }

        private struct ImageSource: Codable {
            var type: String
            var mediaType: String
            var data: String

            enum CodingKeys: String, CodingKey {
                case type
                case mediaType = "media_type"
                case data
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case "image":
                let source = try container.decode(ImageSource.self, forKey: .source)
                self = .image(mediaType: source.mediaType, base64: source.data)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown tool_result content type: \(type)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .image(let mediaType, let base64):
                try container.encode("image", forKey: .type)
                try container.encode(
                    ImageSource(type: "base64", mediaType: mediaType, data: base64),
                    forKey: .source
                )
            }
        }
    }

    fileprivate struct ResponseBody: Decodable {
        var content: [APIContentBlock]
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    fileprivate static func toAPITool(_ tool: AgentTool) -> APITool {
        APITool(
            name: tool.name,
            description: tool.description,
            inputSchema: tool.inputSchema
        )
    }

    fileprivate static func toAPIMessage(_ message: AgentMessage) -> APIMessage {
        APIMessage(
            role: message.role == .user ? "user" : "assistant",
            content: message.content.map(toAPIBlock)
        )
    }

    fileprivate static func toAPIBlock(_ block: AgentContent) -> APIContentBlock {
        switch block {
        case .text(let text):
            return .text(text)
        case .toolUse(let id, let name, let input):
            return .toolUse(id: id, name: name, input: input)
        case .toolResult(let id, let content, let isError, let image):
            var blocks: [APIToolResultContent] = [.text(content)]
            if let image {
                blocks.append(
                    .image(
                        mediaType: image.mediaType,
                        base64: image.data.base64EncodedString()
                    )
                )
            }
            return .toolResult(
                toolUseId: id,
                content: blocks,
                isError: isError ? true : nil
            )
        }
    }

    fileprivate static func fromAPIResponse(_ response: ResponseBody) -> AgentResponse {
        let content: [AgentContent] = response.content.compactMap { block in
            switch block {
            case .text(let text):
                .text(text)
            case .toolUse(let id, let name, let input):
                .toolUse(id: id, name: name, input: input)
            case .toolResult(let id, let content, let isError):
                // tool_result blocks are not expected from the assistant, but
                // round-trip them anyway. Collapse to the text portion only —
                // any echoed image blocks are dropped.
                .toolResult(
                    toolUseId: id,
                    content: content.compactMap { block in
                        if case .text(let text) = block {
                            return text
                        }
                        return nil
                    }.joined(separator: "\n"),
                    isError: isError ?? false,
                    image: nil
                )
            }
        }
        let stopReason: AgentStopReason = switch response.stopReason {
        case "end_turn":
            .endTurn
        case "tool_use":
            .toolUse
        case "max_tokens":
            .maxTokens
        case "stop_sequence":
            .stopSequence
        case .some(let value):
            .other(value)
        case .none:
            .other("unknown")
        }
        return AgentResponse(content: content, stopReason: stopReason)
    }
}
