import SwiftUI

struct RootContainer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var tripPlanningSession = TripPlanningSession()
    @State private var responseCoordinator =
        GIAResponseCoordinator()
    @State private var judgeDemoController =
        JudgeDemoController()
    @State private var planningOrchestrator =
        TripPlanningOrchestrator(
            service: GIAAssistantServiceFactory.make()
        )
    @State private var planTranslationCoordinator =
        PlanTranslationCoordinator(
            service: GIAAssistantServiceFactory.make()
        )
    @State private var connectivityMonitor =
        GIAConnectivityMonitor()

    var body: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            activeScreen
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigationBar(
                selection: appState.selectedTab,
                onSelect: selectTab
            )
        }
        .environment(appState)
        .environment(tripPlanningSession)
        .environment(responseCoordinator)
        .environment(judgeDemoController)
        .environment(planningOrchestrator)
        .environment(planTranslationCoordinator)
        .environment(connectivityMonitor)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            appState.updateApplicationActivity(
                applicationActivity(for: newPhase)
            )
            if newPhase != .active {
                responseCoordinator.stop()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didReceiveMemoryWarningNotification
            )
        ) { _ in
            responseCoordinator.purgeCachedAudio()
        }
    }

    @ViewBuilder
    private var activeScreen: some View {
        ZStack {
            MapScreen(isActive: appState.allowsEarthRendering)
                .opacity(appState.isMapSelected ? 1 : 0)
                .allowsHitTesting(appState.isMapSelected)
                .accessibilityHidden(!appState.isMapSelected)

            switch appState.selectedTab {
            case .plan:
                PlanScreen()
                    .transition(.opacity)
            case .map:
                EmptyView()
            case .group:
                GroupScreen()
                    .transition(.opacity)
            }
        }
    }

    private func selectTab(_ tab: AppTab) {
        withAnimation(tabAnimation) {
            appState.select(tab)
        }
    }

    private var tabAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : GIAMotion.quick
    }

    private func applicationActivity(
        for scenePhase: ScenePhase
    ) -> ApplicationActivity {
        switch scenePhase {
        case .active:
            .active
        case .inactive:
            .inactive
        case .background:
            .background
        @unknown default:
            .inactive
        }
    }

}

struct RootContainer_Previews: PreviewProvider {
    static var previews: some View {
        RootContainer()
            .preferredColorScheme(.dark)
    }
}
