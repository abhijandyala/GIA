import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var selectedTab: AppTab = .map
    private(set) var isMenuPresented = false
    private(set) var applicationActivity: ApplicationActivity = .active
    private(set) var assistantReplyMode: GIATypedReplyMode?
    private(set) var pendingMapFollowUp = false

    init() {
        #if DEBUG
        if
            let rawTab = ProcessInfo.processInfo.environment[
                "GIA_DEBUG_INITIAL_TAB"
            ],
            let tab = AppTab(rawValue: rawTab)
        {
            selectedTab = tab
        } else if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_GROUP_WORKSPACE"
        ] == "1" {
            selectedTab = .group
        }
        #endif
    }

    var isMapSelected: Bool {
        selectedTab == .map
    }

    var allowsEarthRendering: Bool {
        isMapSelected && applicationActivity.permitsLiveRendering
    }

    func select(_ tab: AppTab) {
        selectedTab = tab
        isMenuPresented = false
    }

    func setAssistantReplyMode(_ mode: GIATypedReplyMode?) {
        assistantReplyMode = mode
    }

    func requestMapFollowUp() {
        pendingMapFollowUp = true
    }

    func consumePendingMapFollowUp() -> Bool {
        let pending = pendingMapFollowUp
        pendingMapFollowUp = false
        return pending
    }

    func toggleMenu() {
        guard isMapSelected, applicationActivity == .active else {
            isMenuPresented = false
            return
        }

        isMenuPresented.toggle()
    }

    func dismissMenu() {
        isMenuPresented = false
    }

    func updateApplicationActivity(_ activity: ApplicationActivity) {
        applicationActivity = activity

        if activity != .active {
            isMenuPresented = false
        }
    }
}
