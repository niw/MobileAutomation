//
//  MainView.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI

enum Route: Hashable {
    case transcript
}

struct MainView: View {
    @Environment(AnyAgentService.self)
    private var service

    @Environment(AnyAirPlayScreenshotService.self)
    private var receiver

    @State
    private var path = NavigationPath()

    @State
    private var isSettingsPresented: Bool = false

    var body: some View {
        @Bindable
        var service = service

        NavigationStack(path: $path) {
            List {
                deviceSection
                airPlaySection
                goalSection
                transcriptSection
            }
            .navigationTitle("Mobile Automation Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if service.isRunning {
                        Button(role: .destructive) {
                            service.stopRun()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                    } else {
                        Button {
                            service.startRun()
                        } label: {
                            Label("Run", systemImage: "play.fill")
                        }
                        .disabled(
                            !service.isConnected ||
                                service.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
            .sheet(isPresented: $isSettingsPresented) {
                NavigationStack {
                    SettingsView()
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { service.lastError != nil },
                    set: { newValue in
                        if !newValue {
                            service.lastError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    service.lastError = nil
                }
            } message: {
                Text(service.lastError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section("Device") {
            switch service.connectionState {
            case .disconnected:
                HStack {
                    Label("Disconnected", systemImage: "circle.dotted")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Connect") {
                        service.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .connecting:
                HStack {
                    ProgressView()
                    Text("Connecting…")
                    Spacer()
                }
            case .connected(let name):
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Connected")
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button("Disconnect") {
                        service.disconnect()
                    }
                    .buttonStyle(.bordered)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Button("Retry") {
                            service.connect()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var airPlaySection: some View {
        Section {
            Label {
                HStack {
                    Text("AirPlay")
                    Spacer()
                    Text(receiver.isMirroring ? "Mirroring" : "Waiting")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } icon: {
                Image(systemName: receiver.isMirroring ? "rectangle.on.rectangle" : "rectangle.on.rectangle.slash")
                    .foregroundStyle(receiver.isMirroring ? .green : .secondary)
            }
        } header: {
            Text("Screen")
        } footer: {
            Text("Open Control Center and start Screen Mirroring to “\(AirPlayScreenshotService.defaultName)”.")
        }
    }

    @ViewBuilder
    private var goalSection: some View {
        @Bindable
        var service = service

        Section {
            TextField(
                "e.g. \"Open Settings and toggle Wi-Fi.\"",
                text: $service.goal,
                axis: .vertical
            )
            .lineLimit(3 ... 10)
            .autocorrectionDisabled()
            runStateRow
        } header: {
            Text("Goal")
        } footer: {
            if !service.isConnected {
                Text("Connect to a device to run the agent.")
            }
        }
    }

    @ViewBuilder
    private var runStateRow: some View {
        switch service.runState {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Running…")
                    .foregroundStyle(.secondary)
            }
        case .finished(let success, let summary):
            Label {
                Text(summary?.isEmpty == false ? summary! : (success ? "Completed" : "Stopped"))
                    .lineLimit(3)
            } icon: {
                Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(success ? .green : .orange)
            }
        case .failed(let message):
            Label {
                Text(message)
                    .lineLimit(3)
            } icon: {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private var transcriptSection: some View {
        Section("Transcript") {
            NavigationLink(value: Route.transcript) {
                Label {
                    HStack {
                        Text("Agent Transcript")
                        Spacer()
                        if !service.transcript.isEmpty {
                            Text("\(service.transcript.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "text.bubble")
                }
            }
        }
    }

    // MARK: - Routing

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .transcript:
            TranscriptView()
        }
    }
}

#Preview("Idle") {
    MainView()
        .previewEnvironment()
}

#Preview("Connected") {
    MainView()
        .environment(
            PreviewAgentService(
                connectionState: .connected(deviceName: "Pico Controller")
            )
            .eraseToAnyAgentService()
        )
        .previewEnvironment()
}

#Preview("Running") {
    MainView()
        .environment(
            PreviewAgentService(
                connectionState: .connected(deviceName: "Pico Controller"),
                transcript: PreviewAgentService.sampleTranscript,
                runState: .running,
                goal: "Open Settings and toggle Wi-Fi."
            )
            .eraseToAnyAgentService()
        )
        .previewEnvironment()
}
