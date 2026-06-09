//
//  KeyButton.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI

struct KeyButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    HStack(spacing: 8) {
        KeyButton("Tab", systemImage: "arrow.right.to.line.compact") {
        }
        KeyButton("Return", systemImage: "return") {
        }
        KeyButton("Esc", systemImage: "escape") {
        }
        KeyButton("Space", systemImage: "space") {
        }
    }
    .padding()
}
