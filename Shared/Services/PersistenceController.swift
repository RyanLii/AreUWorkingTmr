import Foundation
import SwiftData

enum PersistenceController {
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([DrinkRecordModel.self, UserProfileModel.self])

        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            #if DEBUG
            print("CloudKit container unavailable, falling back to local: \(error)")
            #endif
            let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Unable to create local model container: \(error)")
            }
        }
    }
}
