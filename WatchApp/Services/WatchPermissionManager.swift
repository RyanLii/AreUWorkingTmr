import Foundation
import CoreLocation
import UserNotifications

@MainActor
final class WatchPermissionManager: NSObject, ObservableObject {
    @Published private(set) var notificationAuthorized = false
    @Published private(set) var locationAuthorized = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func refreshStatus() {
        let locationStatus = locationManager.authorizationStatus
        locationAuthorized = locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestBaselinePermissions() {
        requestNotificationsIfNeeded()
        requestLocationIfNeeded()
    }

    func requestNotificationsIfNeeded() {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["AUTO_WATCH_DEMO"] == "1" {
            return
        }
        #endif

        guard !notificationAuthorized else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.notificationAuthorized = granted
            }
        }
    }

    func requestLocationIfNeeded() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }
}

extension WatchPermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.locationAuthorized = status == .authorizedAlways || status == .authorizedWhenInUse
        }
    }
}
