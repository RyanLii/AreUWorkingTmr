import Foundation
import CoreLocation

@MainActor
final class WatchLocationMonitor: NSObject, ObservableObject {
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isMonitoring = false

    var onPossibleMissedLog: ((TimeInterval, Double) -> Void)?
    var onHomeArrival: ((Date) -> Void)?
    var homeLocation: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()
    private var stableLocation: CLLocation?
    private var stableSince: Date?
    private var hasArrivedHomeThisSession = false
    private var activeSessionKey: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
    }

    func start() {
        guard !isMonitoring else { return }
        locationManager.startUpdatingLocation()
        isMonitoring = true
    }

    func stop() {
        guard isMonitoring else { return }
        locationManager.stopUpdatingLocation()
        isMonitoring = false
    }

    private func processLocation(_ location: CLLocation, now: Date) {
        defer { currentLocation = location }

        refreshSessionIfNeeded(now: now)

        if let stableLocation {
            let distance = location.distance(from: stableLocation)
            if distance > 200,
               let stableSince,
               now.timeIntervalSince(stableSince) >= 20 * 60 {
                onPossibleMissedLog?(now.timeIntervalSince(stableSince), distance)
                self.stableLocation = location
                self.stableSince = now
            } else if distance <= 50 {
                // remain stable
            } else {
                // moved but not enough to count as venue exit
            }
        } else {
            stableLocation = location
            stableSince = now
        }

        if let homeLocation {
            let home = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
            let homeDistance = location.distance(from: home)
            if homeDistance <= 120, !hasArrivedHomeThisSession {
                hasArrivedHomeThisSession = true
                onHomeArrival?(now)
            }
        }
    }

    private func refreshSessionIfNeeded(now: Date) {
        let key = SessionClock.key(for: now)
        guard key != activeSessionKey else { return }

        activeSessionKey = key
        hasArrivedHomeThisSession = false
        stableLocation = nil
        stableSince = nil
    }
}

extension WatchLocationMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.processLocation(last, now: .now)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("Watch location monitor error: \(error)")
        #endif
    }
}
