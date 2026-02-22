import SwiftUI
import SwiftData

@main
struct AreUWorkingTmrWatchExtensionApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var permissionManager = WatchPermissionManager()
    @StateObject private var locationMonitor = WatchLocationMonitor()
    @StateObject private var connectivity = WatchConnectivityManager()
    private let modelContainer: ModelContainer

    init() {
        self.modelContainer = PersistenceController.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(permissionManager)
                .environmentObject(locationMonitor)
                .onAppear {
                    connectivity.store = store
                    store.connectivity = connectivity
                }
        }
        .modelContainer(modelContainer)
    }
}
