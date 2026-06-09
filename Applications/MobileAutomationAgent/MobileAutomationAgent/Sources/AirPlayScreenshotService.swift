//
//  AirPlayScreenshotService.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 6/8/26.
//

import AirPlayScreenshot
import Foundation
import Observation
import UIKit

struct AirPlayCapture {
    var pngData: Data
    var imageSize: CGSize
    var sourceSize: CGSize
    var scale: CGFloat
}

@MainActor
protocol AirPlayScreenshotServiceProtocol: AnyObject, Observable {
    var isMirroring: Bool { get }
    var sourceSize: CGSize { get }

    func start()
    func capture(settle: Duration, scale: CGFloat) async -> AirPlayCapture?
}

@MainActor
@Observable
final class AnyAirPlayScreenshotService: AirPlayScreenshotServiceProtocol {
    private let service: any AirPlayScreenshotServiceProtocol

    init(_ service: some AirPlayScreenshotServiceProtocol) {
        self.service = service
    }

    var isMirroring: Bool {
        service.isMirroring
    }

    var sourceSize: CGSize {
        service.sourceSize
    }

    func start() {
        service.start()
    }

    func capture(settle: Duration, scale: CGFloat) async -> AirPlayCapture? {
        await service.capture(settle: settle, scale: scale)
    }
}

extension AirPlayScreenshotServiceProtocol {
    func eraseToAnyAirPlayScreenshotService() -> AnyAirPlayScreenshotService {
        AnyAirPlayScreenshotService(self)
    }
}

/// Bridges the `Sendable` `AirPlayReceiver` from `AirPlayScreenshot` into an
/// observable, main-actor service the SwiftUI views and the agent can consume.
@MainActor
@Observable
final class AirPlayScreenshotService: AirPlayScreenshotServiceProtocol {
    static let defaultName: String = "Mobile Automation Agent"

    private(set) var isMirroring: Bool = false
    private(set) var sourceSize: CGSize = .zero

    @ObservationIgnored
    private let receiver: AirPlayReceiver

    init(name: String = AirPlayScreenshotService.defaultName, decoderKind: VideoDecoderKind = .openH264) {
        let receiver = AirPlayReceiver(name: name, decoderKind: decoderKind)
        self.receiver = receiver
        // The loop ends when the receiver deallocates and finishes the
        // stream, so the task doesn't need to be retained for cancellation.
        Task { [weak self, events = receiver.events] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    func start() {
        try? receiver.start()
    }

    // MARK: - Receiver events

    private func handle(_ event: AirPlayReceiver.Event) {
        switch event {
        case .mirroringStarted:
            isMirroring = true
        case .disconnected, .mirroringStopped:
            isMirroring = false
        case .videoSizeChanged(let size):
            sourceSize = size
        case .connectionInitiated, .clientConnected:
            break
        }
    }

    func capture(
        settle: Duration = .milliseconds(200),
        scale: CGFloat = 0.5
    ) async -> AirPlayCapture? {
        if settle > .zero {
            try? await Task.sleep(for: settle)
        }
        let receiver = receiver
        let source = sourceSize
        return await Task.detached {
            guard let original = receiver.capture() else {
                return nil
            }
            let scaled: UIImage
            if scale >= 1.0 - .ulpOfOne {
                scaled = original
            } else {
                let newSize = CGSize(
                    width: max(1, original.size.width * scale),
                    height: max(1, original.size.height * scale)
                )
                let format = UIGraphicsImageRendererFormat.default()
                format.scale = 1.0
                format.opaque = true
                let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
                scaled = renderer.image { _ in
                    original.draw(in: CGRect(origin: .zero, size: newSize))
                }
            }
            guard let png = scaled.pngData() else {
                return nil
            }
            return AirPlayCapture(
                pngData: png,
                imageSize: scaled.size,
                sourceSize: source,
                scale: scale
            )
        }.value
    }
}

@MainActor
@Observable
final class PreviewAirPlayScreenshotService: AirPlayScreenshotServiceProtocol {
    var isMirroring: Bool
    var sourceSize: CGSize

    init(
        isMirroring: Bool = false,
        sourceSize: CGSize = .zero
    ) {
        self.isMirroring = isMirroring
        self.sourceSize = sourceSize
    }

    func start() {
    }

    func capture(settle: Duration, scale: CGFloat) async -> AirPlayCapture? {
        nil
    }
}
