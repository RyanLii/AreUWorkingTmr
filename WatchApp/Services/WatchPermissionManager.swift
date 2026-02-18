import Foundation
import CoreLocation
import UserNotifications
import HealthKit

@MainActor
final class WatchPermissionManager: NSObject, ObservableObject {
    @Published private(set) var notificationAuthorized = false
    @Published private(set) var locationAuthorized = false
    @Published private(set) var healthKitAuthorized = false

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()

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

        guard HKHealthStore.isHealthDataAvailable(), let types = healthReadTypes else {
            healthKitAuthorized = false
            return
        }

        healthStore.getRequestStatusForAuthorization(toShare: [], read: types) { status, _ in
            Task { @MainActor in
                self.healthKitAuthorized = status == .unnecessary
            }
        }
    }

    func requestBaselinePermissions() {
        // Temporarily disabled to prevent the notification permission banner
        // from blocking watch demo recordings.
        // requestNotificationsIfNeeded()
        requestLocationIfNeeded()
        requestHealthKitReadIfNeeded()
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

    func requestHealthKitReadIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable(), let types = healthReadTypes else {
            healthKitAuthorized = false
            return
        }

        guard !healthKitAuthorized else { return }

        healthStore.requestAuthorization(toShare: [], read: types) { success, _ in
            Task { @MainActor in
                self.healthKitAuthorized = success
            }
        }
    }

    func loadLatestHealthProfile() async -> (weightKg: Double?, biologicalSex: BiologicalSex?) {
        guard healthKitAuthorized else {
            return (nil, nil)
        }

        async let weightKg = latestBodyMassKg()
        let biologicalSex = latestBiologicalSex()
        return (await weightKg, biologicalSex)
    }

    private var healthReadTypes: Set<HKObjectType>? {
        guard
            let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex)
        else {
            return nil
        }

        return [bodyMassType, biologicalSexType]
    }

    private func latestBodyMassKg() async -> Double? {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(returning: kg > 0 ? kg : nil)
            }

            self.healthStore.execute(query)
        }
    }

    private func latestBiologicalSex() -> BiologicalSex? {
        do {
            let healthSex = try healthStore.biologicalSex().biologicalSex
            switch healthSex {
            case .male: return .male
            case .female: return .female
            default: return nil
            }
        } catch {
            return nil
        }
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
