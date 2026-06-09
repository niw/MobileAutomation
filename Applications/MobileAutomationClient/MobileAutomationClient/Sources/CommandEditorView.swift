//
//  CommandEditorView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import MobileAutomationSupport
import SwiftUI

/// Top-level dispatcher for per-kind editor views. New-mode is requested by
/// passing `initial: nil` together with the `kind`; edit-mode passes an
/// existing `Command` (its `kind` is used as the editor type).
struct CommandEditorView: View {
    @Environment(AnyMainService.self)
    private var service

    var kind: CommandKind
    var initial: Command?

    var body: some View {
        Group {
            switch kind {
            case .tapKey:
                TapKeyEditorView(initial: initial, onCommit: commit)
            case .typeText:
                TypeTextEditorView(initial: initial, onCommit: commit)
            case .moveMouse:
                MoveScrollEditorView(kind: .moveMouse, initial: initial, onCommit: commit)
            case .scrollMouse:
                MoveScrollEditorView(kind: .scrollMouse, initial: initial, onCommit: commit)
            case .click:
                ClickEditorView(kind: .click, initial: initial, onCommit: commit)
            case .moveAbsoluteMouse:
                AbsoluteMouseEditorView(initial: initial, onCommit: commit)
            case .scrollAbsoluteMouse:
                MoveScrollEditorView(kind: .scrollAbsoluteMouse, initial: initial, onCommit: commit)
            case .absoluteClick:
                ClickEditorView(kind: .absoluteClick, initial: initial, onCommit: commit)
            case .typeBrailleChord:
                BrailleChordEditorView(initial: initial, onCommit: commit)
            case .tapRoutingKey:
                RoutingKeyEditorView(initial: initial, onCommit: commit)
            case .setLED:
                SetLEDEditorView(initial: initial, onCommit: commit)
            case .wait:
                WaitEditorView(initial: initial, onCommit: commit)
            }
        }
    }

    private func commit(_ command: Command) {
        if initial == nil {
            service.addCommand(command)
        } else {
            service.updateCommand(command)
        }
    }
}
