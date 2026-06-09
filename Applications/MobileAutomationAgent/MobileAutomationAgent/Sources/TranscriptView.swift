//
//  TranscriptView.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import AgentSupport
import Foundation
import SwiftUI

struct TranscriptView: View {
    @Environment(AnyAgentService.self)
    private var service

    var body: some View {
        Group {
            if service.transcript.isEmpty {
                ContentUnavailableView(
                    "No Transcript Yet",
                    systemImage: "text.bubble",
                    description: Text("Run the agent to populate the transcript.")
                )
            } else {
                transcriptList
            }
        }
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    service.clearTranscript()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(service.transcript.isEmpty)
            }
        }
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(service.transcript) { entry in
                    TranscriptRow(entry: entry)
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: service.transcript.last?.id) { _, newValue in
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
        TranscriptView()
            .previewEnvironment()
    }
}

#Preview("Populated") {
    NavigationStack {
        TranscriptView()
            .environment(
                PreviewAgentService(transcript: PreviewAgentService.sampleTranscript)
                    .eraseToAnyAgentService()
            )
            .previewEnvironment()
    }
}
