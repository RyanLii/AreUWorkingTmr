import SwiftUI
import SwiftData

struct WatchRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: WatchPermissionManager
    @EnvironmentObject private var locationMonitor: WatchLocationMonitor
    @State private var didBind = false
    @State private var didConfigureRuntime = false

    var body: some View {
        ZStack {
            WatchBackdrop()

            TabView {
                QuickAddView()
                VoiceLogView()
                LiveStatusView()
                TimelineView()
            }
            .tabViewStyle(.verticalPage)
            .safeAreaPadding(.top, 2)
            .safeAreaPadding(.bottom, 2)
        }
        .onAppear {
            guard !didBind else { return }
            didBind = true
            store.bind(modelContext: modelContext)
            locationMonitor.homeLocation = store.profile.homeLocation?.coordinate
        }
        .onAppear {
            guard !didConfigureRuntime else { return }
            didConfigureRuntime = true
            configureRuntime()
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
        .onChange(of: store.profile.homeLocation) { _, _ in
            locationMonitor.homeLocation = store.profile.homeLocation?.coordinate
        }
    }

    private func configureRuntime() {
        permissionManager.refreshStatus()
        permissionManager.requestBaselinePermissions()

        if permissionManager.locationAuthorized {
            locationMonitor.start()
        }

        locationMonitor.onPossibleMissedLog = { stay, moved in
            store.handleLocationTransition(stayedDuration: stay, movedDistanceMeters: moved)
        }
        locationMonitor.onHomeArrival = { arrivedAt in
            store.handleHomeArrival(arrivedAt: arrivedAt)
        }

        syncHealthProfileIfAvailable()
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
