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
    @State private var isSwiping = false

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
            .opacity(offset < 0 ? 1 : 0)

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
        // A larger minimum distance plus a strong horizontal-dominance check makes the
        // swipe deliberate: a tap or a near-vertical scroll never starts revealing the
        // actions, so the card only opens on a clear, intentional left swipe.
        DragGesture(minimumDistance: 28)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                // Lock the gesture's axis on first qualifying movement. Require horizontal
                // travel to clearly dominate (2.5x) before we treat it as a swipe.
                if !isSwiping {
                    guard horizontal > vertical * 2.5, horizontal > 12 else { return }
                    isSwiping = true
                }
                if value.translation.width < 0 {
                    offset = max(value.translation.width, -revealWidth)
                } else if offset < 0 {
                    offset = min(0, -revealWidth + value.translation.width)
                }
            }
            .onEnded { value in
                isSwiping = false
                // Commit to open only when the swipe travels well past half the reveal
                // width OR is flicked quickly; otherwise snap closed. This avoids the card
                // popping open on small/accidental drags.
                let traveled = value.translation.width
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let shouldOpen = traveled < -(revealWidth * 0.62) || (traveled < -36 && velocity < -120)
                withAnimation(.snappy(duration: 0.28)) {
                    offset = shouldOpen ? -revealWidth : 0
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
