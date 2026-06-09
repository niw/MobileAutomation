//
//  LEDBlinker.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/21/26.
//

import Foundation
import MobileAutomationSupport
import Synchronization

/// Toggles the dongle LED between on/off on each call to `advance()` so the
/// physical light gives a visible heartbeat as the agent sends HID events.
final class LEDBlinker: Sendable {
    private let client: Client
    private let isOn = Mutex(false)

    init(client: Client) {
        self.client = client
        try? client.setLED(.off)
    }

    func advance() {
        let next: LEDMode = isOn.withLock { isOn in
            isOn.toggle()
            return isOn ? .on : .off
        }
        try? client.setLED(next)
    }

    func turnOff() {
        isOn.withLock { isOn in
            isOn = false
        }
        try? client.setLED(.off)
    }
}
