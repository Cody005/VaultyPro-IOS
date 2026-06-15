import SwiftUI
import SwiftData

/// Compact list of items with swipe-to-archive / delete actions.
struct CardListView: View {
    let items: [StashItem]
    var onAddToCollection: (StashItem) -> Void
    var onMoveToVault: ((StashItem) -> Void)? = nil

    @Environment(\.modelContext) private var context

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(items) { item in
                SwipeableCard(item: item, cornerRadius: 16) {
                    NavigationLink(value: item) {
                        StashRowView(item: item)
                    }
                    .buttonStyle(CardButtonStyle())
                }
                .contextMenu {
                    ItemContextMenu(item: item, onAddToCollection: onAddToCollection,
                                    onMoveToVault: onMoveToVault)
                }
            }
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }
}

/// Horizontal row used in list mode.
struct StashRowView: View {
    let item: StashItem

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(data: item.thumbnailData, urlString: item.thumbnailURL, contentType: item.contentType)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .center) {
                    if item.contentType == .video {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.stashNavy)
                            .frame(width: 26, height: 26)
                            .background(.white.opacity(0.9), in: Circle())
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: item.contentType.systemImage)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(item.contentType.tint)
                    FaviconView(urlString: item.faviconURL, platform: item.platform, size: 13)
                    Text(item.sourceDomain ?? item.platform?.displayName ?? "Note")
                        .foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 4)
                    if !item.isRead {
                        Circle().fill(Color.stashAmber).frame(width: 6, height: 6)
                    }
                    Text(item.savedAt.relativeShort).foregroundStyle(.tertiary)
                }
                .font(.system(size: 11.5, weight: .medium))

                Text(item.displayTitle)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)

                if let desc = item.itemDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}
