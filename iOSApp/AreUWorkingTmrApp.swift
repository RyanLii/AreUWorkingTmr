import SwiftUI
import SwiftData

@main
struct AreUWorkingTmrApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var locationMonitor = LocationMonitor()

    private let modelContainer: ModelContainer

    init() {
        self.modelContainer = PersistenceController.makeModelContainer()
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
}
