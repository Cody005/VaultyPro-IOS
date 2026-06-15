import SwiftUI
import SwiftData

/// Target for the collection detail screen — a smart filter or a user collection.
enum CollectionTarget: Hashable {
    case smart(SmartCollection)
    case user(Collection)
    case vault(Collection)
}

struct CollectionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(VaultManager.self) private var vault
    @Query(sort: \StashItem.savedAt, order: .reverse) private var items: [StashItem]
    @Query(filter: #Predicate<Collection> { !$0.isSmart && !$0.isVault },
           sort: \Collection.sortOrder) private var collections: [Collection]
    @Query(filter: #Predicate<Collection> { $0.isVault }) private var vaultCollections: [Collection]
    @Environment(ProStatusManager.self) private var pro
    @State private var model = CollectionsViewModel()
    @State private var showPaywall = false
    @State private var showVaultSetup = false
    @State private var showVaultUnlock = false
    @State private var navPath = NavigationPath()

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader("Collections") {
                        HeaderActionGroup {
                            Button {
                                if !pro.isPro && collections.count >= AppConfig.Free.maxCollections {
                                    showPaywall = true
                                } else {
                                    model.showingNewCollection = true
                                }
                            } label: { Image(systemName: "plus") }
                        }
                    }
                    smartSection
                    vaultSection
                    userSection
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CollectionTarget.self) { target in
                switch target {
                case .smart, .user: CollectionDetailView(target: target)
                case .vault(let c): VaultContentView(vaultCollection: c)
                }
            }
            .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
            .sheet(isPresented: $showVaultSetup, onDismiss: openVaultIfUnlocked) {
                VaultSetupView()
            }
            .sheet(isPresented: $showVaultUnlock, onDismiss: openVaultIfUnlocked) {
                VaultUnlockView()
            }
            .sheet(isPresented: $model.showingNewCollection) {
                CollectionEditorSheet(model: model, isRename: false) {
                    model.createCollection(in: context, existingCount: collections.count)
                }
            }
            .sheet(item: $model.renameTarget) { _ in
                CollectionEditorSheet(model: model, isRename: true) {
                    model.rename(in: context)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: - Vault section

    @ViewBuilder
    private var vaultSection: some View {
        if let vaultCol = vaultCollections.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vault")
                    .font(AppFont.sectionHeader())
                    .padding(.horizontal, AppMetrics.hPadding)

                LazyVGrid(columns: grid, spacing: 14) {
                    vaultCard(vaultCol)
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
    }

    /// Pushes the vault content once the setup/unlock sheet has fully dismissed.
    /// Doing this in `onDismiss` (rather than racing the sheet close) prevents the
    /// navigation from being dropped while the sheet is mid-dismissal.
    private func openVaultIfUnlocked() {
        guard vault.vaultState == .unlocked, let v = vaultCollections.first else { return }
        navPath.append(CollectionTarget.vault(v))
    }

    @ViewBuilder
    private func vaultCard(_ collection: Collection) -> some View {
        let cardLabel = VaultCollectionCardView(
            isLocked: vault.vaultState != .unlocked,
            isSetup: vault.vaultState != .notSetup,
            itemCount: collection.itemCount
        )
        if vault.vaultState == .unlocked {
            NavigationLink(value: CollectionTarget.vault(collection)) {
                cardLabel
            }
            .buttonStyle(CardButtonStyle())
        } else {
            Button { handleVaultTap() } label: { cardLabel }
                .buttonStyle(CardButtonStyle())
        }
    }

    private func handleVaultTap() {
        switch vault.vaultState {
        case .notSetup: showVaultSetup = true
        case .locked:   showVaultUnlock = true
        case .unlocked: break
        }
    }

    // MARK: - Smart section

    private var smartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart")
                .font(AppFont.sectionHeader())
                .padding(.horizontal, AppMetrics.hPadding)

            LazyVGrid(columns: grid, spacing: 14) {
                ForEach(SmartCollection.allCases) { smart in
                    let matching = items.filter { smart.matches($0) }
                    NavigationLink(value: CollectionTarget.smart(smart)) {
                        CollectionCardView(
                            emoji: smart.emoji, name: smart.name,
                            colorHex: smart.colorHex, count: matching.count,
                            covers: Array(matching.prefix(4))
                        )
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
    }

    @ViewBuilder
    private var userSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Collections")
                .font(AppFont.sectionHeader())
                .padding(.horizontal, AppMetrics.hPadding)

            if collections.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No collections yet",
                    message: "Group saves into folders like Read Later, Recipes or Inspiration.",
                    ctaTitle: "New Collection",
                    action: { model.showingNewCollection = true }
                )
            } else {
                LazyVGrid(columns: grid, spacing: 14) {
                    ForEach(collections) { collection in
                        NavigationLink(value: CollectionTarget.user(collection)) {
                            CollectionCardView(
                                emoji: collection.emoji, name: collection.name,
                                colorHex: collection.colorHex, count: collection.itemCount,
                                covers: collection.coverThumbnails
                            )
                        }
                        .buttonStyle(CardButtonStyle())
                        .contextMenu {
                            Button { model.beginRename(collection) } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                model.delete(collection, in: context)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .padding(.horizontal, AppMetrics.hPadding)
            }
        }
    }
}

/// Collection card with a 2x2 cover mosaic.
struct CollectionCardView: View {
    let emoji: String
    let name: String
    let colorHex: String
    let count: Int
    let covers: [StashItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mosaic
                .frame(height: 110)
                .clipped()
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(emoji)
                    Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(AppFont.metadata()).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background(Color.stashCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius).strokeBorder(Color.primary.opacity(0.05)))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }

    @ViewBuilder
    private var mosaic: some View {
        if covers.isEmpty {
            LinearGradient(colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Text(emoji).font(.system(size: 40)))
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                ForEach(0..<4, id: \.self) { index in
                    if index < covers.count {
                        ThumbnailView(data: covers[index].thumbnailData,
                                      urlString: covers[index].thumbnailURL,
                                      contentType: covers[index].contentType)
                            .frame(height: 54).clipped()
                    } else {
                        Color(hex: colorHex).opacity(0.3).frame(height: 54)
                    }
                }
            }
        }
    }
}

// MARK: - Vault collection card

struct VaultCollectionCardView: View {
    let isLocked: Bool
    let isSetup: Bool
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#4A1D96"), Color(hex: "#2D1B69")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if !isSetup {
                    Text("Set up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.stashNavy)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.stashAmber, in: Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("🔒")
                    Text("Vault").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
                Text(isLocked
                     ? (isSetup ? "Tap to unlock" : "Tap to set up")
                     : "\(itemCount) private item\(itemCount == 1 ? "" : "s")")
                    .font(AppFont.metadata()).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background(Color.stashCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius).strokeBorder(Color.primary.opacity(0.05)))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }
}
