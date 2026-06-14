import Foundation
import SwiftData

/// Builds the shared SwiftData container used by both the app and the Share Extension.
///
/// Storage strategy:
/// - Prefer the App Group container so the extension and app see the same data.
/// - If the App Group container is unavailable (e.g. running unsigned in the Simulator),
///   gracefully fall back to the default local location so the app still launches.
/// - CloudKit sync is opt-in via `AppConfig.cloudKitEnabled`.
enum Persistence {
    static let schema = Schema([StashItem.self, Collection.self, Highlight.self])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }

        let configuration = makeConfiguration()
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Last-resort fallback so the UI never hard-crashes during development.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }

    private static func makeConfiguration() -> ModelConfiguration {
        let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)?
            .appendingPathComponent(AppConfig.storeFileName)

        if AppConfig.cloudKitEnabled {
            if let groupURL {
                return ModelConfiguration(schema: schema, url: groupURL,
                                          cloudKitDatabase: .automatic)
            }
            return ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        }

        if let groupURL {
            return ModelConfiguration(schema: schema, url: groupURL)
        }
        // No entitlement available (unsigned Simulator) — use default location.
        return ModelConfiguration(schema: schema)
    }
}
