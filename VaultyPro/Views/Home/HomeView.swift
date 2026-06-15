import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(VaultManager.self) private var vault
    @Query(sort: \StashItem.savedAt, order: .reverse) private var allItems: [StashItem]
    @Query(filter: #Predicate<Collection> { $0.isVault }) private var vaultCollections: [Collection]
    @State private var model = HomeViewModel()
    @State private var loading = true
    @State private var movingItem: StashItem?
    @State private var pendingVaultItem: StashItem?
    @State private var showVaultUnlock = false
    @State private var showVaultSetup = false

    private var items: [StashItem] { model.filtered(allItems) }

    private var counts: [HomeFilter: Int] {
        var dict: [HomeFilter: Int] = [.all: 0]
        for item in allItems where !item.isArchived && !item.isInVault {
            dict[.all, default: 0] += 1
            dict[.type(item.contentType), default: 0] += 1
        }
        return dict
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14, pinnedViews: []) {
                    ScreenHeader("Your Inbox") {
                        HeaderActionGroup {
                            Button {
                                model.layout = model.layout == .grid ? .list : .grid
                            } label: {
                                Image(systemName: model.layout.systemImage)
                            }
                            Button { model.showQuickAdd = true } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                    subheader
                    FilterChipsView(selection: $model.filter, counts: counts)

                    if loading {
                        skeletons
                    } else if items.isEmpty {
                        EmptyStateView(
                            icon: "tray",
                            title: "Nothing here yet",
                            message: "Share to VaultyPro from any app, or tap + to paste a link.",
                            ctaTitle: "Quick Add",
                            action: { model.showQuickAdd = true }
                        )
                        .padding(.top, 20)
                    } else {
                        content
                            .padding(.bottom, 24)
                    }
                }
                .padding(.top, 4)
            }
            .background(AppBackground())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await refresh() }
            .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
            .sheet(isPresented: $model.showQuickAdd) { QuickAddView() }
            .sheet(item: $movingItem) { item in
                CollectionPickerSheet(item: item)
            }
            .sheet(isPresented: $showVaultSetup) {
                VaultSetupView()
                    .onChange(of: vault.vaultState) { _, new in
                        if new == .unlocked, let item = pendingVaultItem,
                           let vaultCol = vaultCollections.first {
                            showVaultSetup = false
                            vault.moveToVault(item, vaultCollection: vaultCol, in: context)
                            pendingVaultItem = nil
                        }
                    }
            }
            .sheet(isPresented: $showVaultUnlock) {
                VaultUnlockView()
                    .onChange(of: vault.vaultState) { _, new in
                        if new == .unlocked, let item = pendingVaultItem,
                           let vaultCol = vaultCollections.first {
                            showVaultUnlock = false
                            vault.moveToVault(item, vaultCollection: vaultCol, in: context)
                            pendingVaultItem = nil
                        }
                    }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.easeOut(duration: 0.3)) { loading = false }
            }
        }
    }

    // MARK: - Sections

    private var subheader: some View {
        let today = model.savedToday(allItems)
        return HStack(spacing: 6) {
            Text(model.greeting).foregroundStyle(.secondary)
            if today > 0 {
                Text("·").foregroundStyle(.secondary)
                Text("\(today) saved today").foregroundStyle(Color.stashAmber)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, AppMetrics.hPadding)
    }

    @ViewBuilder
    private var content: some View {
        if model.layout == .grid {
            CardGridView(items: items, onAddToCollection: { movingItem = $0 },
                         onMoveToVault: handleMoveToVault)
        } else {
            CardListView(items: items, onAddToCollection: { movingItem = $0 },
                         onMoveToVault: handleMoveToVault)
        }
    }

    private var skeletons: some View {
        LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in SkeletonCardView() }
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }

    private func handleMoveToVault(_ item: StashItem) {
        guard vaultCollections.first != nil else { return }
        switch vault.vaultState {
        case .notSetup:
            pendingVaultItem = item
            showVaultSetup = true
        case .locked:
            pendingVaultItem = item
            showVaultUnlock = true
        case .unlocked:
            guard let vaultCol = vaultCollections.first else { return }
            vault.moveToVault(item, vaultCollection: vaultCol, in: context)
        }
    }

    private func refresh() async {
        model.isRefreshing = true
        // Re-enrich items still missing a thumbnail/metadata.
        for item in allItems where item.thumbnailData == nil && item.url != nil && item.contentType != .note {
            await ItemSaver.enrich(item, in: context)
        }
        try? await Task.sleep(for: .milliseconds(300))
        model.isRefreshing = false
    }
}
