//
//  BackgroundAudioManager.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import AVFoundation
import Foundation

@MainActor
final class BackgroundAudioManager {
    private let audioPlayer: AVPlayer

    init() {
        let playerItem = AVPlayerItem(url: URL(fileURLWithPath: ""))
        audioPlayer = AVPlayer(playerItem: playerItem)

        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.playback, mode: .default, options: .mixWithOthers)
        } catch {
            print("Error setting up background audio session: \(error)")
        }
    }

    private func setActive(_ state: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(state)
        } catch {
            print("Error setting background audio state: \(error)")
        }
    }

    func start() {
        setActive(true)
        audioPlayer.play()
    }

    func stop() {
        audioPlayer.pause()
        setActive(false)
    }
}
