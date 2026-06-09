//
//  KeychainTokenStorage.swift
//  AppSupport
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import Security

@MainActor
public struct KeychainTokenStorage: TokenStorage {
    public enum Error: Swift.Error, LocalizedError {
        case encodingFailed
        case decodingFailed
        case unhandled(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Failed to encode the value."
            case .decodingFailed:
                return "Failed to decode the value."
            case .unhandled(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
                return "Keychain error: \(message)"
            }
        }
    }

    public var service: String

    public init(service: String) {
        self.service = service
    }

    public func read(for key: String) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8)
            else {
                throw Error.decodingFailed
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw Error.unhandled(status)
        }
    }

    public func write(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw Error.encodingFailed
        }

        let query = baseQuery(for: key)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw Error.unhandled(addStatus)
            }
        default:
            throw Error.unhandled(updateStatus)
        }
    }

    public func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw Error.unhandled(status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
