//
//  MainView.swift
//  MobileAutomationClient
//
//  Created by Yoshimasa Niwa on 5/18/26.
//

import Foundation
import SwiftUI

enum Route: Hashable {
    case palette
    case newCommand(CommandKind)
    case editCommand(Command.ID)
    case log
}

struct MainView: View {
    @Environment(AnyMainService.self)
    private var service

    @State
    private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                deviceSection
                scriptSection
                logSection
            }
            .navigationTitle("Mobile Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !service.commands.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if service.isRunning {
                        Button(role: .destructive) {
                            service.cancelRun()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                    } else {
                        Button {
                            service.runCommands()
                        } label: {
                            Label("Run", systemImage: "play.fill")
                        }
                        .disabled(service.commands.isEmpty || !service.isConnected)
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
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

    private var scriptSection: some View {
        Section {
            ForEach(service.commands) { command in
                NavigationLink(value: Route.editCommand(command.id)) {
                    CommandRow(command: command)
                }
            }
            .onDelete { offsets in
                service.deleteCommands(at: offsets)
            }
            .onMove { source, destination in
                service.moveCommands(from: source, to: destination)
            }

            NavigationLink(value: Route.palette) {
                Label("Add Command…", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Script")
                Spacer()
                if !service.commands.isEmpty {
                    Text("\(service.commands.count)")
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if service.commands.isEmpty {
                Text("Add commands to build a script, then tap Run.")
            }
        }
    }

    private var logSection: some View {
        Section("Log") {
            NavigationLink(value: Route.log) {
                Label {
                    HStack {
                        Text("Communication Log")
                        Spacer()
                        if !service.logEntries.isEmpty {
                            Text("\(service.logEntries.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "text.alignleft")
                }
            }
        }
    }

    // MARK: - Routing

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .palette:
            CommandPaletteView()
        case .newCommand(let kind):
            CommandEditorView(kind: kind, initial: nil)
        case .editCommand(let id):
            if let command = service.command(id: id) {
                CommandEditorView(kind: command.kind, initial: command)
            } else {
                ContentUnavailableView(
                    "Command Not Found",
                    systemImage: "questionmark.circle",
                    description: Text("It may have been deleted.")
                )
            }
        case .log:
            LogView()
        }
    }
}

#Preview("Disconnected") {
    MainView()
        .environment(PreviewMainService().eraseToAnyMainService())
}

#Preview("Connected — empty script") {
    MainView()
        .environment(
            PreviewMainService(
                connectionState: .connected(deviceName: "Pico MIDI HID Composite")
            )
            .eraseToAnyMainService()
        )
}

#Preview("Connected — with script + log") {
    MainView()
        .environment(
            PreviewMainService(
                connectionState: .connected(deviceName: "Pico MIDI HID Composite"),
                commands: PreviewMainService.sampleCommands,
                logEntries: PreviewMainService.sampleLog
            )
            .eraseToAnyMainService()
        )
}
