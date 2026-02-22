import SwiftUI
import SwiftData
import UIKit

@main
struct AreUWorkingTmrApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var locationMonitor = LocationMonitor()
    @StateObject private var connectivity = PhoneConnectivityManager()
    @State private var showSplash = true

    private let modelContainer: ModelContainer

    init() {
        self.modelContainer = PersistenceController.makeModelContainer()
        configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()

                if showSplash {
                    LaunchSplashView()
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            Task {
                                try? await Task.sleep(nanoseconds: 2_800_000_000)
                                withAnimation(.easeOut(duration: 0.55)) {
                                    showSplash = false
                                }
                            }
                        }
                }
            }
            .environmentObject(store)
            .environmentObject(permissionManager)
            .environmentObject(locationMonitor)
            .environmentObject(connectivity)
            .onAppear {
                connectivity.store = store
                store.connectivity = connectivity

                permissionManager.refreshStatus()

                if permissionManager.locationAuthorized {
                    locationMonitor.start()
                }

                locationMonitor.onPossibleMissedLog = { stay, moved in
                    store.handleLocationTransition(stayedDuration: stay, movedDistanceMeters: moved)
                }
                locationMonitor.onHomeArrival = { arrivedAt in
                    store.handleHomeArrival(arrivedAt: arrivedAt)
                }
            }
            .onChange(of: permissionManager.locationAuthorized) { _, authorized in
                if authorized {
                    locationMonitor.start()
                } else {
                    locationMonitor.stop()
                }
            }
        }
        .modelContainer(modelContainer)
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }
}
