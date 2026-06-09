//
//  LogView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import Foundation
import SwiftUI

struct LogView: View {
    @Environment(AnyMainService.self)
    private var service

    var body: some View {
        Group {
            if service.logEntries.isEmpty {
                ContentUnavailableView(
                    "No Log Yet",
                    systemImage: "text.alignleft",
                    description: Text("Run a script to populate the log.")
                )
            } else {
                logList
            }
        }
        .navigationTitle("Communication Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    service.clearLog()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(service.logEntries.isEmpty)
            }
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(service.logEntries) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: service.logEntries.last?.id) { _, newValue in
                guard let newValue else {
                    return
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        LogView()
            .environment(PreviewMainService().eraseToAnyMainService())
    }
}

#Preview("Populated") {
    NavigationStack {
        LogView()
            .environment(
                PreviewMainService(logEntries: PreviewMainService.sampleLog)
                    .eraseToAnyMainService()
            )
    }
}
