import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProStatusManager.self) private var pro
    @Query(sort: \StashItem.savedAt, order: .reverse) private var items: [StashItem]
    @State private var model = SearchViewModel()
    @State private var movingItem: StashItem?
    @State private var showPaywall = false
    @FocusState private var focused: Bool

    private var results: [StashItem] { model.results(from: items) }
    private var locked: Bool { !pro.isPro && !model.query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ScreenHeader("Search")
                searchField
                filterBar

                ScrollView {
                    if locked {
                        proLock
                    } else if model.query.isEmpty && model.typeFilter == nil && !model.unreadOnly {
                        recentsSection
                    } else if results.isEmpty {
                        EmptyStateView(icon: "magnifyingglass",
                                       title: "No matches",
                                       message: "Try a different keyword, tag, or filter.")
                            .padding(.top, 30)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(results) { item in
                                NavigationLink(value: item) {
                                    SearchResultRow(item: item, query: model.query)
                                }
                                .buttonStyle(CardButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppMetrics.hPadding)
                        .padding(.top, 4)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
            .padding(.top, 4)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
            .sheet(item: $movingItem) { CollectionPickerSheet(item: $0) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onChange(of: focused) { _, isFocused in if !isFocused { model.commitRecent() } }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search titles, tags, notes…", text: $model.query)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { model.commitRecent() }
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.stashMuted.opacity(0.2)))
        .padding(.horizontal, AppMetrics.hPadding)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterPill(title: "Unread", active: model.unreadOnly) { model.unreadOnly.toggle() }
                ForEach(ContentType.allCases) { type in
                    filterPill(title: type.pluralTitle, icon: type.systemImage,
                               active: model.typeFilter == type) {
                        model.typeFilter = model.typeFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
        }
    }

    private func filterPill(title: String, icon: String? = nil, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(active ? Color.stashNavy : .primary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(active ? AnyShapeStyle(Color.stashAmber) : AnyShapeStyle(Color.stashCardSurface), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.stashMuted.opacity(active ? 0 : 0.2)))
        }
        .buttonStyle(.plain)
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.recents.isEmpty {
                EmptyStateView(icon: "clock.arrow.circlepath",
                               title: "Search your vault",
                               message: "Find anything you've saved by title, tag, domain or note.")
                    .padding(.top, 20)
            } else {
                HStack {
                    Text("Recent").font(AppFont.sectionHeader())
                    Spacer()
                    Button("Clear") { model.clearRecents() }.font(.system(size: 13)).tint(Color.stashAmber)
                }
                .padding(.horizontal, AppMetrics.hPadding)

                ForEach(model.recents, id: \.self) { recent in
                    Button { model.query = recent } label: {
                        HStack {
                            Image(systemName: "clock").foregroundStyle(.secondary)
                            Text(recent).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left").foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, AppMetrics.hPadding).padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var proLock: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.stashAmber)
            Text("Full-text search is a Pro feature")
                .font(.system(size: 18, weight: .bold)).multilineTextAlignment(.center)
            Text("Upgrade to VaultyPro Pro to search across everything you save.")
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Button("Upgrade to Pro") { showPaywall = true }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.stashNavy)
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Color.stashAmber, in: Capsule())
        }
        .padding(.top, 50)
    }
}

/// Search result row with highlighted matches.
struct SearchResultRow: View {
    let item: StashItem
    let query: String

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(data: item.thumbnailData, urlString: item.thumbnailURL, contentType: item.contentType)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                highlighted(item.displayTitle)
                    .font(AppFont.cardTitle()).lineLimit(2)
                HStack(spacing: 5) {
                    TypeBadgeView(type: item.contentType, compact: true)
                    Text(item.sourceDomain ?? item.savedAt.relativeShort)
                        .font(AppFont.metadata()).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.05)))
    }

    private func highlighted(_ text: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespaces)
        var attributed = AttributedString(text)
        attributed.foregroundColor = .primary
        if !q.isEmpty, let range = attributed.range(of: q, options: .caseInsensitive) {
            attributed[range].foregroundColor = .stashAmber
            attributed[range].font = .system(size: 15, weight: .bold)
        }
        return Text(attributed)
    }
}
