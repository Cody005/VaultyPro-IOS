import SwiftUI
import SwiftData

/// Uniform two-column grid of cards.
struct CardGridView: View {
    let items: [StashItem]
    var onAddToCollection: (StashItem) -> Void
    var onMoveToVault: ((StashItem) -> Void)? = nil

    @Environment(\.modelContext) private var context

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(items) { item in
                SwipeableCard(item: item, cornerRadius: 22) {
                    NavigationLink(value: item) {
                        StashCardView(item: item)
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

/// Wraps a card so a left-swipe reveals Archive and Delete actions. Works inside a
/// `ScrollView`/grid where SwiftUI's native `List.swipeActions` is unavailable.
struct SwipeableCard<Content: View>: View {
    let item: StashItem
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @State private var offset: CGFloat = 0

    private let actionWidth: CGFloat = 78

    private var revealWidth: CGFloat { actionWidth * 2 }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                actionButton("archivebox", "Archive", Color.stashAmber) {
                    reset()
                    withAnimation { ItemActions.archive(item, in: context) }
                }
                actionButton("trash", "Delete", Color.stashRed) {
                    reset()
                    withAnimation { ItemActions.delete(item, in: context, undo: undo) }
                }
            }
            .frame(width: revealWidth)

            content
                .offset(x: offset)
                .overlay {
                    if offset != 0 {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { reset() }
                    }
                }
                .simultaneousGesture(dragGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func actionButton(_ icon: String, _ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .background(color)
        }
        .buttonStyle(.plain)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0 {
                    offset = max(value.translation.width, -revealWidth)
                } else if offset < 0 {
                    offset = min(0, -revealWidth + value.translation.width)
                }
            }
            .onEnded { value in
                withAnimation(.snappy(duration: 0.25)) {
                    offset = value.translation.width < -revealWidth / 2 ? -revealWidth : 0
                }
            }
    }

    private func reset() {
        withAnimation(.snappy(duration: 0.25)) { offset = 0 }
    }
}

/// Shared context-menu actions used by grid cards.
struct ItemContextMenu: View {
    let item: StashItem
    var onAddToCollection: (StashItem) -> Void
    var onMoveToVault: ((StashItem) -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo

    var body: some View {
        Button { ItemActions.toggleRead(item, in: context) } label: {
            Label(item.isRead ? "Mark Unread" : "Mark Read",
                  systemImage: item.isRead ? "circle" : "checkmark.circle")
        }
        Button { ItemActions.toggleFavorite(item, in: context) } label: {
            Label(item.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: item.isFavorite ? "star.slash" : "star")
        }
        Button { onAddToCollection(item) } label: {
            Label("Add to Collection", systemImage: "folder.badge.plus")
        }
        if let onMoveToVault {
            Button { onMoveToVault(item) } label: {
                Label("Move to Vault", systemImage: "lock.fill")
            }
        }
        Button { ItemActions.archive(item, in: context) } label: {
            Label("Archive", systemImage: "archivebox")
        }
        Divider()
        Button(role: .destructive) { ItemActions.delete(item, in: context, undo: undo) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
