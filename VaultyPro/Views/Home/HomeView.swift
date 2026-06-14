import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StashItem.savedAt, order: .reverse) private var allItems: [StashItem]
    @State private var model = HomeViewModel()
    @State private var loading = true
    @State private var movingItem: StashItem?

    private var items: [StashItem] { model.filtered(allItems) }

    private var counts: [HomeFilter: Int] {
        var dict: [HomeFilter: Int] = [.all: 0]
        for item in allItems where !item.isArchived {
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
            CardGridView(items: items) { movingItem = $0 }
        } else {
            CardListView(items: items) { movingItem = $0 }
        }
    }

    private var skeletons: some View {
        LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in SkeletonCardView() }
        }
        .padding(.horizontal, AppMetrics.hPadding)
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
