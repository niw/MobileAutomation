//
//  AgentLiveActivity.swift
//  MobileAutomationAgentWidget
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct AgentLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    statusIcon(state: context.state)
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("step \(context.state.step)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.statusText)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.goal)
                            .font(.subheadline)
                            .lineLimit(2)
                        if let last = context.state.lastUpdate, !last.isEmpty {
                            Text(last)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                statusIcon(state: context.state)
            } compactTrailing: {
                Text("\(context.state.step)")
                    .font(.caption.monospacedDigit())
            } minimal: {
                statusIcon(state: context.state)
            }
        }
    }

    private func lockScreen(context: ActivityViewContext<AgentActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                statusIcon(state: context.state)
                    .font(.title3)
                Text(context.state.statusText)
                    .font(.headline)
                Spacer()
                Text("step \(context.state.step)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(context.attributes.goal)
                .font(.subheadline)
                .lineLimit(2)
            if let last = context.state.lastUpdate, !last.isEmpty {
                Text(last)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusIcon(state: AgentActivityAttributes.ContentState) -> some View {
        if state.isFinished {
            switch state.success {
            case true?:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case false?:
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            case nil:
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.orange)
            }
        } else {
            Image(systemName: "play.circle.fill")
                .foregroundStyle(.blue)
        }
    }
}
