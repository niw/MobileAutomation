//
//  PromptProfileDetailed.swift
//  MobileAutomationAgent
//
//  Created by Yoshimasa Niwa on 5/19/26.
//

import ActionSupport
import AgentSupport
import Foundation

extension PromptProfile {
    static let detailedSystemPrompt = """
    You are an iOS automation agent. You drive a real iOS device via a \
    USB HID dongle (keyboard + mouse) and see its screen through AirPlay.

    # Perception

    Every action result is prefixed `screen W×H, image w×h (scale s); …` \
    and includes a fresh screenshot. The image is for *looking*; plan \
    distances in **source-screen pixels** (= image coord ÷ scale). If \
    the prefix is `screen unavailable; …`, retry with \
    `screen_capture({ wait_ms: 1000 })`.

    # Mouse

    Use **`mouse_move_to({ x, y })`** — `x`/`y` are source-screen \
    pixels (the same units as the `screen W×H` prefix). The cursor \
    jumps directly to the target coordinate, no acceleration, no \
    calibration. Read the target's coordinate off the screenshot, \
    convert image pixels to source pixels (divide by `scale`), and \
    pass them in.

    To click an icon, button, or any small UI control: **aim \
    precisely.** Pick the visual centre of the target on the \
    screenshot (not "somewhere inside the bounding box"), call \
    `mouse_move_to({ x, y })`, then verify on the next screenshot \
    that the cursor is actually on the target before calling \
    `mouse_click`. A 4–6 pt miss can land on an adjacent element or \
    on empty padding and silently do nothing — re-aim and re-move \
    rather than clicking and hoping.

    The iOS pointer in the screenshot appears as a **faint, round \
    circle (~25 pt across at 1×)** — sometimes **black** on light \
    backgrounds, sometimes **white** on dark backgrounds. It's easy \
    to miss; inspect the area around the expected coordinate \
    carefully. It also sometimes doesn't render in the captured \
    frame at all even when iOS shows it on the device, so a missing \
    circle isn't proof the cursor isn't there — hover / focus \
    highlights on the target are equally good confirmation.

    # Typing

    `keyboard_type_text` sends keys to whatever is focused — confirm \
    a text field looks focused first. `keyboard_send_shortcut` covers \
    `home`, `return`, `escape`, `spotlight`, `app_switcher`, \
    `screenshot`, etc.

    # Loop

    screenshot → plan one action → call the tool → fresh screenshot \
    comes back → repeat. **One action per call.** Permission / system \
    alerts can steal focus; read before dismissing. A locked device \
    blocks everything — bail with `done({ success: false })` rather \
    than spinning. Call `done({ summary, success })` when finished or \
    proven impossible.

    **Stay on task.** Every action must move you closer to the goal. \
    Don't tap UI elements out of curiosity, don't open unrelated apps \
    or menus, don't "explore" the screen, and don't poke at \
    notifications or banners that aren't blocking your progress. If \
    you accidentally open something extra, back out (`escape`, `home`, \
    or the back gesture) and resume the original plan. Extraneous \
    clicks waste turns and risk leaving the device in a state you \
    have to recover from.
    """

    static let detailedTools: [AgentTool] = [
        AgentTool(
            name: "screen_capture",
            description: "Take a fresh screenshot. Optional `wait_ms` (0-5000) waits before capturing.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "wait_ms": .object([
                        "type": .string("integer"),
                        "minimum": .int(0),
                        "maximum": .int(5000),
                    ]),
                ]),
            ])
        ),
        AgentTool(
            name: "mouse_move_to",
            description: "Move the cursor to absolute (`x`, `y`) in source-screen pixels. No acceleration, no calibration — the cursor jumps directly to the target.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "x": .object(["type": .string("integer")]),
                    "y": .object(["type": .string("integer")]),
                ]),
                "required": .array([.string("x"), .string("y")]),
            ])
        ),
        AgentTool(
            name: "mouse_click",
            description: "Click a mouse button at the current cursor position. Defaults to `left`.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "button": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("left"),
                            .string("right"),
                            .string("middle"),
                            .string("back"),
                            .string("forward"),
                        ]),
                    ]),
                ]),
            ])
        ),
        AgentTool(
            name: "mouse_scroll",
            description: "Scroll at the current cursor position. `vertical` positive scrolls down; `horizontal` positive scrolls right.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "vertical": .object(["type": .string("integer")]),
                    "horizontal": .object(["type": .string("integer")]),
                ]),
            ])
        ),
        AgentTool(
            name: "keyboard_tap_key",
            description: "Press one HID Usage ID (0-255) with optional modifiers (`ctrl`, `shift`, `alt`, `gui`).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "usage": .object([
                        "type": .string("integer"),
                        "minimum": .int(0),
                        "maximum": .int(255),
                    ]),
                    "modifiers": .object([
                        "type": .string("array"),
                        "items": .object([
                            "type": .string("string"),
                            "enum": .array([
                                .string("ctrl"),
                                .string("shift"),
                                .string("alt"),
                                .string("gui"),
                            ]),
                        ]),
                    ]),
                ]),
                "required": .array([.string("usage")]),
            ])
        ),
        AgentTool(
            name: "keyboard_type_text",
            description: "Type ASCII text into the currently focused text field.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object(["type": .string("string")]),
                ]),
                "required": .array([.string("text")]),
            ])
        ),
        AgentTool(
            name: "keyboard_send_shortcut",
            description: "Run a named keyboard shortcut (e.g. `home`, `return`, `escape`, `app_switcher`, `spotlight`, `screenshot`).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "shortcut": .object([
                        "type": .string("string"),
                        "enum": .array(KeyboardCommand.allCases.map { .string($0.rawValue) }),
                    ]),
                ]),
                "required": .array([.string("shortcut")]),
            ])
        ),
        AgentTool(
            name: agentDoneToolName,
            description: "Signal completion. The agent loop stops after this call.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "summary": .object(["type": .string("string")]),
                    "success": .object(["type": .string("boolean")]),
                ]),
                "required": .array([.string("summary"), .string("success")]),
            ])
        ),
    ]
}
