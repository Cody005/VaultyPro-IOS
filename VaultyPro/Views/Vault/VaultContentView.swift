import SwiftUI
import SwiftData

/// Shows vault items after the vault has been unlocked.
struct VaultContentView: View {
    let vaultCollection: Collection

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultManager.self) private var vault
    @State private var movingItem: StashItem?

    private var items: [StashItem] {
        (vaultCollection.items ?? [])
            .filter { $0.isInVault }
            .sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                EmptyStateView(
                    icon: "lock.open",
                    title: "Vault is empty",
                    message: "Long-press any item and choose Move to Vault to save it here privately."
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            StashCardView(item: item)
                        }
                        .buttonStyle(CardButtonStyle())
                        .contextMenu {
                            vaultItemMenu(item)
                        }
                    }
                }
                .padding(.horizontal, AppMetrics.hPadding)
                .padding(.vertical, 12)
            }
        }
        .background(AppBackground())
        .scrollIndicators(.hidden)
        .navigationTitle("🔒 Vault")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vault.keepAlive() }
        .onScrollPhaseChange { _, phase in
            if phase == .interacting { vault.keepAlive() }
        }
        .onChange(of: vault.vaultState) { _, state in
            if state != .unlocked { dismiss() }
        }
        .sheet(item: $movingItem) { CollectionPickerSheet(item: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vault.lock()
                } label: {
                    Image(systemName: "lock")
                        .font(.system(size: 16, weight: .semibold))
                }
                .tint(Color.stashAmber)
            }
        }
    }

    @ViewBuilder
    private func vaultItemMenu(_ item: StashItem) -> some View {
        Button {
            ItemActions.toggleRead(item, in: context)
        } label: {
            Label(item.isRead ? "Mark Unread" : "Mark Read",
                  systemImage: item.isRead ? "circle" : "checkmark.circle")
        }
        Button {
            ItemActions.toggleFavorite(item, in: context)
        } label: {
            Label(item.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: item.isFavorite ? "star.slash" : "star")
        }
        Divider()
        Button {
            vault.removeFromVault(item, in: context)
        } label: {
            Label("Move to Inbox", systemImage: "tray.and.arrow.up")
        }
        Button { movingItem = item } label: {
            Label("Move to Collection", systemImage: "folder.badge.plus")
        }
        Divider()
        Button(role: .destructive) {
            ItemActions.delete(item, in: context)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
