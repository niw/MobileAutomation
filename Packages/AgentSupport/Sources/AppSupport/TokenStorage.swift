//
//  TokenStorage.swift
//  AppSupport
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation

@MainActor
public protocol TokenStorage {
    func read(for key: String) throws -> String?
    func write(_ value: String, for key: String) throws
    func delete(key: String) throws
}
