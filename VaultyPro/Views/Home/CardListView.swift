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
                NavigationLink(value: item) {
                    StashRowView(item: item)
                }
                .buttonStyle(CardButtonStyle())
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
        HStack(spacing: 13) {
            ThumbnailView(data: item.thumbnailData, urlString: item.thumbnailURL, contentType: item.contentType)
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
                .overlay(alignment: .center) {
                    if item.contentType == .video {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.stashNavy)
                            .frame(width: 26, height: 26)
                            .background(.white.opacity(0.9), in: Circle())
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayTitle)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    FaviconView(urlString: item.faviconURL, platform: item.platform, size: 13)
                    Text(item.sourceDomain ?? item.platform?.displayName ?? "Note")
                        .foregroundStyle(.secondary).lineLimit(1)
                    if let mins = item.estimatedReadTime, item.contentType == .article {
                        Text("·").foregroundStyle(.tertiary)
                        Text("\(mins) min").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(item.savedAt.relativeShort).foregroundStyle(.tertiary)
                }
                .font(.system(size: 11.5, weight: .medium))

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 0)

            VStack {
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.stashAmber)
                } else if !item.isRead {
                    Circle().fill(Color.stashAmber).frame(width: 7, height: 7)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(11)
        .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}
