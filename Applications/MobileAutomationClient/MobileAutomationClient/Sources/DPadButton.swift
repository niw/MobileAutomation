//
//  DPadButton.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI

struct DPadButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    VStack(spacing: 8) {
        DPadButton(systemImage: "arrow.up") {
        }
        HStack(spacing: 8) {
            DPadButton(systemImage: "arrow.left") {
            }
            DPadButton(systemImage: "cursorarrow.click") {
            }
            DPadButton(systemImage: "arrow.right") {
            }
        }
        DPadButton(systemImage: "arrow.down") {
        }
    }
    .padding()
}
