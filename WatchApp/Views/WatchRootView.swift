import SwiftUI
import SwiftData

struct WatchRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: WatchPermissionManager
    @EnvironmentObject private var locationMonitor: WatchLocationMonitor
    enum DemoTab: Hashable {
        case quickAdd, voice, live, timeline
    }

    @State private var didBind = false
    @State private var didConfigureRuntime = false
    @State private var selectedTab: DemoTab = .quickAdd
    @State private var demoTask: Task<Void, Never>?
    @State private var demoCaption: String? = nil

    var body: some View {
        ZStack {
            WatchBackdrop()

            TabView(selection: $selectedTab) {
                QuickAddView()
                    .tag(DemoTab.quickAdd)
                VoiceLogView()
                    .tag(DemoTab.voice)
                LiveStatusView()
                    .tag(DemoTab.live)
                TimelineView()
                    .tag(DemoTab.timeline)
            }
            .tabViewStyle(.verticalPage)
            .safeAreaPadding(.top, 2)
            .safeAreaPadding(.bottom, 2)

            if let demoCaption {
                VStack {
                    Text(demoCaption)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.45))
                        )
                        .padding(.top, 6)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
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
        .onAppear {
            startAutoDemoIfNeeded()
        }
        .onDisappear {
            demoTask?.cancel()
            demoTask = nil
        }
    }

    private func configureRuntime() {
        permissionManager.refreshStatus()

        #if targetEnvironment(simulator)
        let isAutoDemo = ProcessInfo.processInfo.environment["AUTO_WATCH_DEMO"] == "1"
        #else
        let isAutoDemo = false
        #endif

        if !isAutoDemo {
            permissionManager.requestBaselinePermissions()
        }

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

    private func startAutoDemoIfNeeded() {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["AUTO_WATCH_DEMO"] == "1" else { return }

        demoTask?.cancel()
        demoTask = Task { @MainActor in
            store.clearAllData()
            selectedTab = .quickAdd
            demoCaption = "Swipe to beer"
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            NotificationCenter.default.post(name: .watchDemoAction, object: nil, userInfo: ["action": "tapBeer"])
            demoCaption = "Tap Beer"
            try? await Task.sleep(nanoseconds: 1_600_000_000)

            NotificationCenter.default.post(name: .watchDemoAction, object: nil, userInfo: ["action": "pickBeerSize"])
            demoCaption = "Pick size"
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            NotificationCenter.default.post(name: .watchDemoAction, object: nil, userInfo: ["action": "pickBeerABV"])
            demoCaption = "Set ABV"
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            NotificationCenter.default.post(name: .watchDemoAction, object: nil, userInfo: ["action": "scrollBottom"])
            demoCaption = "Scroll to bottom"
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            NotificationCenter.default.post(name: .watchDemoAction, object: nil, userInfo: ["action": "logBeer"])
            demoCaption = "Log drink"
            try? await Task.sleep(nanoseconds: 1_800_000_000)

            let wine = store.preset(for: .wine)
            let cocktail = store.preset(for: .cocktail)
            store.addQuickDrink(preset: wine, count: 1)
            demoCaption = "Add wine"
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            store.addQuickDrink(preset: cocktail, count: 1)
            demoCaption = "Add cocktail"
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            selectedTab = .timeline
            demoCaption = "Timeline updated"
            try? await Task.sleep(nanoseconds: 1_800_000_000)

            selectedTab = .quickAdd
            NotificationCenter.default.post(name: .watchDemoAction, object: nil, userInfo: ["action": "doneTonight"])
            demoCaption = "I'm done tonight"
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            store.handleHomeArrival(arrivedAt: .now)
            selectedTab = .live
            demoCaption = "Back home simulated"
            try? await Task.sleep(nanoseconds: 2_500_000_000)

            selectedTab = .timeline
            demoCaption = "Final recap"
            try? await Task.sleep(nanoseconds: 1_700_000_000)

            demoCaption = nil
        }
        #endif
    }
}
