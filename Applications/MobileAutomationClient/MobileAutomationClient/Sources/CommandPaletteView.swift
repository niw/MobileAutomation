//
//  CommandPaletteView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct CommandPaletteView: View {
    var body: some View {
        List {
            Section {
                ForEach(CommandKind.allCases) { kind in
                    NavigationLink(value: Route.newCommand(kind)) {
                        Label(kind.displayName, systemImage: kind.systemImage)
                    }
                }
            } footer: {
                Text("Pick a command type to add to the script.")
            }
        }
        .navigationTitle("Add Command")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CommandPaletteView()
    }
}
