import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let target: CollectionTarget
    @Environment(\.modelContext) private var context
    @Query(sort: \StashItem.savedAt, order: .reverse) private var allItems: [StashItem]
    @State private var movingItem: StashItem?

    private var title: String {
        switch target {
        case .smart(let s):  return s.name
        case .user(let c):   return c.name
        case .vault(let c):  return c.name
        }
    }

    private var emoji: String {
        switch target {
        case .smart(let s):  return s.emoji
        case .user(let c):   return c.emoji
        case .vault(let c):  return c.emoji
        }
    }

    private var items: [StashItem] {
        switch target {
        case .smart(let smart):
            return allItems.filter { smart.matches($0) }
        case .user(let collection):
            return (collection.items ?? []).filter { !$0.isInVault }.sorted { $0.savedAt > $1.savedAt }
        case .vault(let collection):
            return (collection.items ?? []).filter { $0.isInVault }.sorted { $0.savedAt > $1.savedAt }
        }
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "Empty for now",
                    message: "Items you add to \(title) will appear here."
                )
                .padding(.top, 40)
            } else {
                CardGridView(items: items) { movingItem = $0 }
                    .padding(.vertical, 12)
            }
        }
        .background(AppBackground())
        .scrollIndicators(.hidden)
        .navigationTitle("\(emoji) \(title)")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
        .sheet(item: $movingItem) { CollectionPickerSheet(item: $0) }
    }
}
