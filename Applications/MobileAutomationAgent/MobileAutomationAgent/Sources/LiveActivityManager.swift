//
//  LiveActivityManager.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    private var activity: Activity<AgentActivityAttributes>?
    private var step: Int = 0

    func start(goal: String) {
        guard activity == nil else {
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        let attributes = AgentActivityAttributes(goal: goal)
        let initialState = AgentActivityAttributes.ContentState(
            statusText: "Running…",
            lastUpdate: nil,
            step: 0,
            isFinished: false,
            success: nil
        )
        step = 0
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: initialState, staleDate: nil),
            pushType: nil
        )
    }

    func update(statusText: String, lastUpdate: String?) {
        guard let activity else {
            return
        }
        step &+= 1
        let state = AgentActivityAttributes.ContentState(
            statusText: statusText,
            lastUpdate: lastUpdate,
            step: step,
            isFinished: false,
            success: nil
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    func finish(success: Bool, summary: String?) {
        guard let activity else {
            return
        }
        let state = AgentActivityAttributes.ContentState(
            statusText: success ? "Done" : "Failed",
            lastUpdate: summary,
            step: step,
            isFinished: true,
            success: success
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.end(content, dismissalPolicy: .after(.now + 30))
        }
        self.activity = nil
    }

    func stop() {
        guard let activity else {
            return
        }
        let state = AgentActivityAttributes.ContentState(
            statusText: "Stopped",
            lastUpdate: nil,
            step: step,
            isFinished: true,
            success: nil
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
