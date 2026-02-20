import Foundation
import CoreLocation
import UserNotifications

@MainActor
final class PermissionManager: NSObject, ObservableObject {
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

    func requestAllAtLaunch() {
        requestNotifications()
        requestLocation()
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.notificationAuthorized = granted
            }
        }
    }

    func requestLocation() {
        locationManager.requestAlwaysAuthorization()
    }
}

extension PermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.locationAuthorized = status == .authorizedAlways || status == .authorizedWhenInUse
        }
    }
}
