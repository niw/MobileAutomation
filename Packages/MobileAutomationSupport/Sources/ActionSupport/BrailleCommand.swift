import Foundation

/// Logical grouping for `BrailleCommand`, mirroring the sections of
/// Apple's published reference: https://support.apple.com/en-us/118665
public enum BrailleCommandCategory: String, Sendable, CaseIterable, Codable {
    case navigation
    case scrolling
    case rotor
    case interaction
    case reading
    case editing
    case control
    case braille

    public var displayName: String {
        switch self {
        case .navigation: "Navigation"
        case .scrolling: "Scrolling"
        case .rotor: "Rotor"
        case .interaction: "Interaction"
        case .reading: "Reading"
        case .editing: "Editing"
        case .control: "Control"
        case .braille: "Braille"
        }
    }
}

/// VoiceOver Braille chord commands defined by Apple.
///
/// Source: https://support.apple.com/en-us/118665
///
/// The raw value is a snake_case identifier suitable for tool / API
/// payloads. Several commands share the same chord on purpose — iOS
/// interprets the same dots differently depending on focus / rotor
/// context (e.g. `startDictation` and `playPauseMusic` are both
/// Space + 1-5-6). `appSwitcher` additionally requires Space to be
/// pressed twice, which the basic `BrailleChord` model does not
/// represent; senders that care must handle the repeat themselves.
public enum BrailleCommand: String, Sendable, CaseIterable, Codable {
    // Navigation
    case previousItem = "previous_item"
    case nextItem = "next_item"
    case firstItem = "first_item"
    case lastItem = "last_item"
    case itemChooser = "item_chooser"
    case statusBar = "status_bar"
    case notificationCenter = "notification_center"
    case controlCenter = "control_center"
    case escape
    case leftSplitViewApp = "left_split_view_app"
    case rightSplitViewApp = "right_split_view_app"
    case previousContainer = "previous_container"
    case nextContainer = "next_container"

    // Scrolling
    case scrollLeftPage = "scroll_left_page"
    case scrollRightPage = "scroll_right_page"
    case scrollUpPage = "scroll_up_page"
    case scrollDownPage = "scroll_down_page"
    case speakPageNumber = "speak_page_number"

    // Rotor
    case previousRotorItem = "previous_rotor_item"
    case nextRotorItem = "next_rotor_item"
    case previousRotorSetting = "previous_rotor_setting"
    case nextRotorSetting = "next_rotor_setting"

    // Interaction
    case simpleTap = "simple_tap"
    case home
    case volumeUp = "volume_up"
    case volumeDown = "volume_down"
    case toggleKeyboard = "toggle_keyboard"
    case touch3D = "touch_3d"

    // Reading
    case readFromSelectedItem = "read_from_selected_item"
    case readFromTop = "read_from_top"

    // Editing
    case selectAll = "select_all"
    case selectLeft = "select_left"
    case selectRight = "select_right"
    case tab
    case shiftTab = "shift_tab"
    case cut
    case copy
    case paste
    case delete
    case `return`
    case undoTyping = "undo_typing"
    case redoTyping = "redo_typing"
    case textSearch = "text_search"
    case outputTextStyle = "output_text_style"
    case startDictation = "start_dictation"

    // Control
    case toggleScreenCurtain = "toggle_screen_curtain"
    case pauseOrContinueSpeech = "pause_or_continue_speech"
    case toggleSpeech = "toggle_speech"
    /// Same dot pattern as `home`; iOS uses Space pressed twice. Senders
    /// that rely solely on `chord` will trigger `home`, not the App
    /// Switcher.
    case appSwitcher = "app_switcher"
    case help
    case changeLabel = "change_label"
    case toggleQuickNav = "toggle_quick_nav"
    /// Same chord as `startDictation`; the active rotor / focus decides
    /// which action iOS performs.
    case playPauseMusic = "play_pause_music"

    // Braille
    case panBrailleLeft = "pan_braille_left"
    case panBrailleRight = "pan_braille_right"
    case toggleAnnouncementHistory = "toggle_announcement_history"
    case translate
    case nextOutputMode = "next_output_mode"
    case nextInputMode = "next_input_mode"
    /// Same chord as `nextOutputMode` — Apple lists both names.
    case switchBrailleContraction = "switch_braille_contraction"
    case toggleMute = "toggle_mute"
    case startHelp = "start_help"
    case simulatedLongPress = "simulated_long_press"
    case singleLetterQuickNav = "single_letter_quick_nav"

    public var chord: BrailleChord {
        switch self {
        // Navigation
        case .previousItem: BrailleChord(1, space: true)
        case .nextItem: BrailleChord(4, space: true)
        case .firstItem: BrailleChord(1, 2, 3, space: true)
        case .lastItem: BrailleChord(4, 5, 6, space: true)
        case .itemChooser: BrailleChord(2, 4, space: true)
        case .statusBar: BrailleChord(2, 3, 4, space: true)
        case .notificationCenter: BrailleChord(4, 6, space: true)
        case .controlCenter: BrailleChord(2, 5, space: true)
        case .escape: BrailleChord(1, 2, space: true)
        case .leftSplitViewApp: BrailleChord(3, 5, space: true)
        case .rightSplitViewApp: BrailleChord(2, 6, space: true)
        case .previousContainer: BrailleChord(1, 7, space: true)
        case .nextContainer: BrailleChord(4, 7, space: true)
        // Scrolling
        case .scrollLeftPage: BrailleChord(2, 4, 6, space: true)
        case .scrollRightPage: BrailleChord(1, 3, 5, space: true)
        case .scrollUpPage: BrailleChord(3, 4, 5, 6, space: true)
        case .scrollDownPage: BrailleChord(1, 4, 5, 6, space: true)
        case .speakPageNumber: BrailleChord(3, 4, space: true)
        // Rotor
        case .previousRotorItem: BrailleChord(3, space: true)
        case .nextRotorItem: BrailleChord(6, space: true)
        case .previousRotorSetting: BrailleChord(2, 3, space: true)
        case .nextRotorSetting: BrailleChord(5, 6, space: true)
        // Interaction
        case .simpleTap: BrailleChord(3, 6, space: true)
        case .home: BrailleChord(1, 2, 5, space: true)
        case .volumeUp: BrailleChord(3, 4, 5, space: true)
        case .volumeDown: BrailleChord(1, 2, 6, space: true)
        case .toggleKeyboard: BrailleChord(1, 4, 6, space: true)
        case .touch3D: BrailleChord(3, 5, 6, space: true)
        // Reading
        case .readFromSelectedItem: BrailleChord(1, 2, 3, 5, space: true)
        case .readFromTop: BrailleChord(2, 4, 5, 6, space: true)
        // Editing
        case .selectAll: BrailleChord(2, 3, 5, 6, space: true)
        case .selectLeft: BrailleChord(2, 3, 5, space: true)
        case .selectRight: BrailleChord(2, 5, 6, space: true)
        case .tab: BrailleChord(2, 3, 4, 5, space: true)
        case .shiftTab: BrailleChord(1, 2, 5, 6, space: true)
        case .cut: BrailleChord(1, 3, 4, 6, space: true)
        case .copy: BrailleChord(1, 4, space: true)
        case .paste: BrailleChord(1, 2, 3, 6, space: true)
        case .delete: BrailleChord(7, space: true)
        case .return: BrailleChord(8, space: true)
        case .undoTyping: BrailleChord(1, 3, 5, 6, space: true)
        case .redoTyping: BrailleChord(2, 3, 4, 6, space: true)
        case .textSearch: BrailleChord(1, 2, 4, space: true)
        case .outputTextStyle: BrailleChord(2, 3, 4, 5, 6, space: true)
        case .startDictation: BrailleChord(1, 5, 6, space: true)
        // Control
        case .toggleScreenCurtain: BrailleChord(1, 2, 3, 4, 5, 6, space: true)
        case .pauseOrContinueSpeech: BrailleChord(1, 2, 3, 4, space: true)
        case .toggleSpeech: BrailleChord(1, 3, 4, space: true)
        case .appSwitcher: BrailleChord(1, 2, 5, space: true)
        case .help: BrailleChord(1, 3, space: true)
        case .changeLabel: BrailleChord(1, 2, 3, 4, 6, space: true)
        case .toggleQuickNav: BrailleChord(1, 2, 3, 4, 5, space: true)
        case .playPauseMusic: BrailleChord(1, 5, 6, space: true)
        // Braille
        case .panBrailleLeft: BrailleChord(2, space: true)
        case .panBrailleRight: BrailleChord(5, space: true)
        case .toggleAnnouncementHistory: BrailleChord(1, 3, 4, 5, space: true)
        case .translate: BrailleChord(4, 5, space: true)
        case .nextOutputMode: BrailleChord(1, 2, 4, 5, space: true)
        case .nextInputMode: BrailleChord(2, 3, 6, space: true)
        case .switchBrailleContraction: BrailleChord(1, 2, 4, 5, space: true)
        case .toggleMute: BrailleChord(1, 3, 4, 7, space: true)
        case .startHelp: BrailleChord(1, 3, 7, space: true)
        case .simulatedLongPress: BrailleChord(3, 6, 7, 8, space: true)
        case .singleLetterQuickNav: BrailleChord(1, 2, 3, 4, 5, 7, space: true)
        }
    }

    public var category: BrailleCommandCategory {
        switch self {
        case .previousItem, .nextItem, .firstItem, .lastItem, .itemChooser,
             .statusBar, .notificationCenter, .controlCenter, .escape,
             .leftSplitViewApp, .rightSplitViewApp,
             .previousContainer, .nextContainer:
            .navigation
        case .scrollLeftPage, .scrollRightPage, .scrollUpPage, .scrollDownPage,
             .speakPageNumber:
            .scrolling
        case .previousRotorItem, .nextRotorItem,
             .previousRotorSetting, .nextRotorSetting:
            .rotor
        case .simpleTap, .home, .volumeUp, .volumeDown, .toggleKeyboard, .touch3D:
            .interaction
        case .readFromSelectedItem, .readFromTop:
            .reading
        case .selectAll, .selectLeft, .selectRight, .tab, .shiftTab,
             .cut, .copy, .paste, .delete, .return,
             .undoTyping, .redoTyping, .textSearch,
             .outputTextStyle, .startDictation:
            .editing
        case .toggleScreenCurtain, .pauseOrContinueSpeech, .toggleSpeech,
             .appSwitcher, .help, .changeLabel, .toggleQuickNav, .playPauseMusic:
            .control
        case .panBrailleLeft, .panBrailleRight, .toggleAnnouncementHistory,
             .translate, .nextOutputMode, .nextInputMode,
             .switchBrailleContraction, .toggleMute, .startHelp,
             .simulatedLongPress, .singleLetterQuickNav:
            .braille
        }
    }

    /// Short human-readable label, matching the action wording from
    /// Apple's reference page.
    public var displayName: String {
        switch self {
        case .previousItem: "Move to previous item"
        case .nextItem: "Move to next item"
        case .firstItem: "Go to first item"
        case .lastItem: "Go to last item"
        case .itemChooser: "Item chooser"
        case .statusBar: "Go to Status bar"
        case .notificationCenter: "Go to Notification Center"
        case .controlCenter: "Go to Control Center"
        case .escape: "Escape current context"
        case .leftSplitViewApp: "Move to Left Split View App"
        case .rightSplitViewApp: "Move to Right Split View App"
        case .previousContainer: "Move to previous container"
        case .nextContainer: "Move to next container"
        case .scrollLeftPage: "Scroll left one page"
        case .scrollRightPage: "Scroll right one page"
        case .scrollUpPage: "Scroll up one page"
        case .scrollDownPage: "Scroll down one page"
        case .speakPageNumber: "Speak page number or rows"
        case .previousRotorItem: "Move to previous item using rotor"
        case .nextRotorItem: "Move to next item using rotor"
        case .previousRotorSetting: "Select previous rotor setting"
        case .nextRotorSetting: "Select next rotor setting"
        case .simpleTap: "Perform simple tap"
        case .home: "Activate Home button"
        case .volumeUp: "Activate Volume Up button"
        case .volumeDown: "Activate Volume Down button"
        case .toggleKeyboard: "Show / Hide keyboard"
        case .touch3D: "3D Touch on selected item"
        case .readFromSelectedItem: "Read page starting at selected item"
        case .readFromTop: "Read page starting at top"
        case .selectAll: "Select all"
        case .selectLeft: "Select left"
        case .selectRight: "Select right"
        case .tab: "Tab"
        case .shiftTab: "Shift Tab"
        case .cut: "Cut"
        case .copy: "Copy"
        case .paste: "Paste"
        case .delete: "Delete"
        case .return: "Return"
        case .undoTyping: "Undo typing"
        case .redoTyping: "Redo typing"
        case .textSearch: "Text search"
        case .outputTextStyle: "Output text style"
        case .startDictation: "Start dictation"
        case .toggleScreenCurtain: "Toggle Screen Curtain"
        case .pauseOrContinueSpeech: "Pause or continue speech"
        case .toggleSpeech: "Toggle speech on / off"
        case .appSwitcher: "App Switcher"
        case .help: "Help"
        case .changeLabel: "Change item's label"
        case .toggleQuickNav: "Toggle QuickNav"
        case .playPauseMusic: "Play / Pause music"
        case .panBrailleLeft: "Pan braille left"
        case .panBrailleRight: "Pan braille right"
        case .toggleAnnouncementHistory: "Toggle announcement history"
        case .translate: "Translate"
        case .nextOutputMode: "Next output mode"
        case .nextInputMode: "Next input mode"
        case .switchBrailleContraction: "Switch contracted / uncontracted"
        case .toggleMute: "Toggle mute"
        case .startHelp: "Start help"
        case .simulatedLongPress: "Simulated long press"
        case .singleLetterQuickNav: "Single-letter quick nav"
        }
    }

    /// All commands in this category, in declaration order.
    public static func commands(in category: BrailleCommandCategory) -> [BrailleCommand] {
        allCases.filter { $0.category == category }
    }
}
