import SwiftUI
import SwiftData

/// Target for the collection detail screen — a smart filter or a user collection.
enum CollectionTarget: Hashable {
    case smart(SmartCollection)
    case user(Collection)
}

struct CollectionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StashItem.savedAt, order: .reverse) private var items: [StashItem]
    @Query(filter: #Predicate<Collection> { !$0.isSmart },
           sort: \Collection.sortOrder) private var collections: [Collection]
    @Environment(ProStatusManager.self) private var pro
    @State private var model = CollectionsViewModel()
    @State private var showPaywall = false

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
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
                    userSection
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CollectionTarget.self) { CollectionDetailView(target: $0) }
            .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
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
