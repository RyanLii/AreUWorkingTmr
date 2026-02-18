import SwiftUI
import SwiftData
import StoreKit

struct RootTabView: View {
    enum Tab: Hashable {
        case today, history, profile, reminders, privacy
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: PermissionManager
    @EnvironmentObject private var locationMonitor: LocationMonitor

    @AppStorage("has_seen_commercial_onboarding") private var hasSeenOnboarding = false

    @State private var didBind = false
    @State private var showOnboarding = false
    @State private var selectedTab: Tab = .today
    @State private var autoTabTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem {
                        Label("Today", systemImage: "moon.stars.fill")
                    }
                    .tag(Tab.today)

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(Tab.history)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    .tag(Tab.profile)

                RemindersView()
                    .tabItem {
                        Label("Reminders", systemImage: "bell.badge")
                    }
                    .tag(Tab.reminders)

                PrivacyView()
                    .tabItem {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                    .tag(Tab.privacy)
            }
            .disabled(showOnboarding)
            .tint(NightTheme.accent)
            .toolbarBackground(Color.black.opacity(0.45), for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)

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
            locationMonitor.homeLocation = store.profile.homeLocation?.coordinate

            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["SKIP_ONBOARDING"] == "1" {
                hasSeenOnboarding = true
            }
            if ProcessInfo.processInfo.environment["AUTO_TAB_DEMO"] == "1" {
                startAutoTabDemo()
            }
            #endif

            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: store.profile.homeLocation) { _, _ in
            locationMonitor.homeLocation = store.profile.homeLocation?.coordinate
        }
        .onChange(of: store.reviewRequestNonce) { _, _ in
            requestReview()
        }
        .onDisappear {
            autoTabTask?.cancel()
            autoTabTask = nil
        }
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
    }

    private func startAutoTabDemo() {
        autoTabTask?.cancel()
        autoTabTask = Task { @MainActor in
            let tabs: [Tab] = [.today, .history, .profile, .reminders, .privacy]
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
