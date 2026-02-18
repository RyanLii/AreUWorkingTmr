import SwiftUI
import SwiftData
import StoreKit

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: PermissionManager
    @EnvironmentObject private var locationMonitor: LocationMonitor

    @AppStorage("has_seen_commercial_onboarding") private var hasSeenOnboarding = false

    @State private var didBind = false
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            TabView {
                TodayView()
                    .tabItem {
                        Label("Today", systemImage: "moon.stars.fill")
                    }

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }

                RemindersView()
                    .tabItem {
                        Label("Reminders", systemImage: "bell.badge")
                    }

                PrivacyView()
                    .tabItem {
                        Label("Privacy", systemImage: "lock.shield")
                    }
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
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
    }
}
