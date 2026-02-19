import SwiftUI
import SwiftData
import UIKit

@main
struct AreUWorkingTmrApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var locationMonitor = LocationMonitor()

    private let modelContainer: ModelContainer

    init() {
        self.modelContainer = PersistenceController.makeModelContainer()
        configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(permissionManager)
                .environmentObject(locationMonitor)
                .onAppear {
                    permissionManager.refreshStatus()
                    syncHealthProfileIfAvailable()

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
                .onChange(of: permissionManager.healthKitAuthorized) { _, authorized in
                    guard authorized else { return }
                    syncHealthProfileIfAvailable()
                }
        }
        .modelContainer(modelContainer)
    }

    private func syncHealthProfileIfAvailable() {
        Task {
            let healthProfile = await permissionManager.loadLatestHealthProfile()
            await MainActor.run {
                store.updateProfileFromHealth(
                    weightKg: healthProfile.weightKg,
                    biologicalSex: healthProfile.biologicalSex
                )
            }
        }
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
