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
        if let vaultCol = vaultCollections.first, collections.isEmpty {
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
                    if let vaultCol = vaultCollections.first {
                        vaultCard(vaultCol)
                    }

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
        ZStack(alignment: .bottomLeading) {
            coverArtwork
            LinearGradient(
                colors: [.clear, .black.opacity(0.14), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            cardInfo
        }
        .frame(height: 176)
        .background(Color.stashCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private var cardInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(emoji)
                    .font(.system(size: 16))
                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Text("\(count) item\(count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coverArtwork: some View {
        GeometryReader { proxy in
            if covers.isEmpty {
                emptyArtwork
            } else if covers.count == 1 {
                coverCell(covers[0])
            } else {
                HStack(spacing: 3) {
                    coverCell(covers[0])
                        .frame(width: proxy.size.width * 0.66)
                    VStack(spacing: 3) {
                        previewCell(at: 1)
                        previewCell(at: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var emptyArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: colorHex).opacity(0.34), Color.stashCardSurface.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 72, height: 72)
            Text(emoji)
                .font(.system(size: 34))
        }
    }

    @ViewBuilder
    private func previewCell(at index: Int) -> some View {
        if index < covers.count {
            coverCell(covers[index])
        } else {
            Color(hex: colorHex).opacity(0.18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func coverCell(_ item: StashItem) -> some View {
        ThumbnailView(data: item.thumbnailData,
                      urlString: item.thumbnailURL,
                      contentType: item.contentType)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Vault collection card

struct VaultCollectionCardView: View {
    let isLocked: Bool
    let isSetup: Bool
    let itemCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            vaultArtwork
            LinearGradient(
                colors: [.clear, .black.opacity(0.12), .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text("🔒")
                        .font(.system(size: 16))
                    Text("Vault")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(isLocked
                     ? (isSetup ? "Tap to unlock" : "Tap to set up")
                     : "\(itemCount) private item\(itemCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 176)
        .background(Color.stashCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if !isSetup {
                Text("Set up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.stashNavy)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.stashAmber, in: Capsule())
                    .padding(10)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private var vaultArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#4A1D96"), Color(hex: "#162238")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 74, height: 74)
            Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}
