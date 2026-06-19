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

    /// Responsive scale anchored to the iPhone 15 Pro Max (932pt logical height), which
    /// is the design reference. On that device the factor is exactly 1.0 so the layout is
    /// unchanged; taller/shorter devices scale vertical metrics proportionally to keep the
    /// same composition. Clamped so it never gets extreme (e.g. on iPad).
    private var uiScale: CGFloat {
        let referenceHeight: CGFloat = 932
        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.height ?? referenceHeight
        return min(max(screenHeight / referenceHeight, 0.82), 1.12)
    }

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
                LazyVStack(spacing: 14 * uiScale, pinnedViews: []) {
                    ScreenHeader("Your Vaulty") {
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
                            .padding(.bottom, 80 * uiScale)
                    }
                }
                .padding(.top, 2)
            }
            .background(AppBackground())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await refresh() }
            .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
            .navigationDestination(for: String.self) { value in
                if value == "saved" {
                    ScrollView {
                        CardListView(items: items, onAddToCollection: { movingItem = $0 },
                                     onMoveToVault: handleMoveToVault)
                            .padding(.top, 8)
                    }
                    .background(AppBackground())
                    .navigationTitle("Saved for later")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
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

    @ViewBuilder
    private var content: some View {
        let hero = items.first
        let rest = Array(items.dropFirst())
        let preview = Array(rest.prefix(3))

        VStack(spacing: 18 * uiScale) {
            if let hero {
                NavigationLink(value: hero) {
                    StashCardView(item: hero, height: 236 * uiScale)
                }
                .buttonStyle(CardButtonStyle())
                .contextMenu {
                    ItemContextMenu(item: hero, onAddToCollection: { movingItem = $0 },
                                    onMoveToVault: handleMoveToVault)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }

            if !preview.isEmpty {
                HStack {
                    Text("Saved for later")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if rest.count > preview.count {
                        NavigationLink(value: "saved") {
                            HStack(spacing: 3) {
                                Text("View all")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Color.stashCardSurface,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppMetrics.hPadding)

                VStack(spacing: 10 * uiScale) {
                    ForEach(preview) { item in
                        NavigationLink(value: item) {
                            StashRowView(item: item)
                        }
                        .buttonStyle(CardButtonStyle())
                        .contextMenu {
                            ItemContextMenu(item: item, onAddToCollection: { movingItem = $0 },
                                            onMoveToVault: handleMoveToVault)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                )
                .padding(.horizontal, AppMetrics.hPadding)
            }
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
