import SwiftUI
import SwiftData

@main
struct VaultyProApp: App {
    @AppStorage("appearancePreference") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var pro = ProStatusManager()
    @State private var undo = UndoCenter()
    private let container = Persistence.makeContainer()

    init() {
        // Generous on-disk + memory cache so thumbnails/favicons load instantly after first fetch.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(pro)
                .environment(undo)
                .tint(Color.stashAmber)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
        .modelContainer(container)
    }
}
