import SwiftUI

/// Central place for shared identifiers and tunables.
/// Change `appGroupID` to your real App Group (e.g. `group.com.YOURTEAMID.vaultypro`)
/// once you set up signing — both the app and the Share Extension must use the same value.
enum AppConfig {
    static let appGroupID = "group.com.vaultypro.app"
    static let storeFileName = "vaultypro.store"

    /// Enable iCloud sync once you've added the iCloud + CloudKit capability and a container.
    static let cloudKitEnabled = false

    /// StoreKit product identifiers (configure in App Store Connect / .storekit file).
    enum Product {
        static let monthly = "com.vaultypro.pro.monthly"
        static let annual  = "com.vaultypro.pro.annual"
    }

    enum Free {
        static let maxItems = 50
        static let maxCollections = 3
    }
}

/// Typography tokens matching the design system.
enum AppFont {
    static func largeTitle() -> Font { .system(size: 30, weight: .bold, design: .default) }
    static func title() -> Font { .system(size: 22, weight: .bold, design: .default) }
    static func sectionHeader() -> Font { .system(size: 17, weight: .semibold, design: .rounded) }
    static func cardTitle() -> Font { .system(size: 15, weight: .medium) }
    static func metadata() -> Font { .system(size: 12, weight: .regular) }
    static func badge() -> Font { .system(size: 10, weight: .semibold) }
}

enum AppMetrics {
    static let cornerRadius: CGFloat = 20
    static let hPadding: CGFloat = 20
}
