import SwiftUI

/// Editorial overlay card — the image fills the whole card and the title + source
/// are laid over a gradient scrim at the bottom for a premium magazine feel.
struct StashCardView: View {
    let item: StashItem
    var height: CGFloat = 236

    private let radius: CGFloat = 22

    var body: some View {
        // A `.fill` image reports a size larger than its container and would push the
        // card wider than its grid column (overflowing the screen). Anchoring the card
        // to a fixed-size Color and rendering the thumbnail as an OVERLAY keeps the
        // layout width pinned to the column — overlays never expand their parent.
        Color.stashCardSurface
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                ThumbnailView(data: item.thumbnailData, urlString: item.thumbnailURL, contentType: item.contentType)
            }
            .clipped()
            .overlay(scrim)
            .overlay(alignment: .top) { topRow }
            .overlay(alignment: .center) { playButton }
            .overlay(alignment: .bottomLeading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
            )
            // Make the entire rounded card a single, reliable tap target so the
            // surrounding NavigationLink opens from anywhere on the card.
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
    }

    /// Bottom-weighted darkening so overlaid text is always legible.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.10), location: 0.45),
                .init(color: .black.opacity(0.62), location: 0.72),
                .init(color: .black.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            TypeChip(type: item.contentType)
            Spacer(minLength: 6)
            if item.isFavorite {
                badge { Image(systemName: "star.fill").foregroundStyle(Color.stashAmber) }
            } else if !item.isRead {
                badge {
                    Circle().fill(Color.stashAmber).frame(width: 7, height: 7)
                }
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var playButton: some View {
        if item.contentType == .video {
            Image(systemName: "play.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.stashNavy)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.95), in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.displayTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

            if let desc = item.itemDescription, !desc.isEmpty, item.contentType != .note {
                Text(desc)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 6) {
                FaviconView(urlString: item.faviconURL, platform: item.platform, size: 15)
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                Text(item.sourceDomain ?? item.platform?.displayName ?? "Note")
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                if let mins = item.estimatedReadTime, item.contentType == .article {
                    metaDot
                    Text("\(mins) min read")
                        .foregroundStyle(Color.stashAmber)
                        .layoutPriority(1)
                }
                Spacer(minLength: 4)
                Text(item.savedAt.relativeShort)
                    .foregroundStyle(.white.opacity(0.62))
                    .layoutPriority(1)
            }
            .font(.system(size: 11.5, weight: .medium))

            if !item.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(.white.opacity(0.14), in: Capsule())
                    }
                }
            }

            if item.contentType == .article && item.readingProgress > 0 && item.readingProgress < 1 {
                ProgressView(value: item.readingProgress)
                    .tint(Color.stashAmber)
                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 13)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaDot: some View {
        Text("·").foregroundStyle(.white.opacity(0.5))
    }

    private func badge<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 11, weight: .bold))
            .frame(width: 26, height: 26)
            .background(.ultraThinMaterial, in: Circle())
            .environment(\.colorScheme, .dark)
    }
}

/// Subtle frosted type chip — monochrome glass with a single colored glyph.
struct TypeChip: View {
    let type: ContentType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(type.tint)
            Text(type.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
    }
}
