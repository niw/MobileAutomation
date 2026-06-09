//
//  KeyboardModifier.swift
//  ActionSupport
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation

/// HID Keyboard modifier bitmap, matching the standard report layout.
public struct KeyboardModifier: OptionSet, Sendable {
    public var rawValue: UInt8
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let leftControl = KeyboardModifier(rawValue: 0x01)
    public static let leftShift = KeyboardModifier(rawValue: 0x02)
    public static let leftAlt = KeyboardModifier(rawValue: 0x04)
    public static let leftGUI = KeyboardModifier(rawValue: 0x08)
    public static let rightControl = KeyboardModifier(rawValue: 0x10)
    public static let rightShift = KeyboardModifier(rawValue: 0x20)
    public static let rightAlt = KeyboardModifier(rawValue: 0x40)
}
