import SwiftUI
import SwiftData
import StoreKit
import Combine

struct RootTabView: View {
    enum Tab: Hashable {
        case today, settings
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: PermissionManager

    @AppStorage("has_seen_commercial_onboarding") private var hasSeenOnboarding = false

    @State private var didBind = false
    @State private var showOnboarding = false
    @State private var selectedTab: Tab = .today
    @State private var autoTabTask: Task<Void, Never>?
    private let liveRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    TodayView()
                }
                    .tabItem {
                        Label("Today", systemImage: "moon.stars.fill")
                    }
                    .tag(Tab.today)

                NavigationStack {
                    SettingsHubView()
                }
                    .tabItem {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .tag(Tab.settings)
            }
            .disabled(showOnboarding)
            .tint(NightTheme.accent)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

            if showOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
                .environmentObject(permissionManager)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            guard !didBind else { return }
            didBind = true
            store.bind(modelContext: modelContext)

            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["SKIP_ONBOARDING"] == "1" {
                hasSeenOnboarding = true
            }
            if let forced = ProcessInfo.processInfo.environment["START_TAB"], let tab = parseTab(forced) {
                selectedTab = tab
            }

            if ProcessInfo.processInfo.environment["AUTO_TAB_DEMO"] == "1" {
                startAutoTabDemo()
            }
            #endif

            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: store.reviewRequestNonce) { _, _ in
            requestReview()
        }
        .onReceive(liveRefreshTimer) { _ in
            store.refreshSnapshot()
        }
        .onDisappear {
            autoTabTask?.cancel()
            autoTabTask = nil
        }
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
        .preferredColorScheme(.dark)
    }

    private func parseTab(_ raw: String) -> Tab? {
        switch raw.lowercased() {
        case "today": return .today
        case "settings", "history", "reminders", "privacy": return .settings
        default: return nil
        }
    }

    private func startAutoTabDemo() {
        autoTabTask?.cancel()
        autoTabTask = Task { @MainActor in
            let tabs: [Tab] = [.today, .settings]
            var index = 0
            try? await Task.sleep(nanoseconds: 800_000_000)
            while !Task.isCancelled {
                selectedTab = tabs[index % tabs.count]
                index += 1
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }
}
