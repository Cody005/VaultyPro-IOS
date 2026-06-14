import SwiftUI

/// In-memory cache of decoded thumbnails so layout switches (grid <-> list) are instant and don't refetch.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private init() { cache.countLimit = 300 }
    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func insert(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

/// Displays a saved item's thumbnail: cached data first, then remote URL (cached), then a gradient placeholder.
struct ThumbnailView: View {
    let data: Data?
    let urlString: String?
    let contentType: ContentType
    var contentMode: ContentMode = .fill

    @State private var loaded: UIImage?

    private var url: URL? {
        guard data == nil, let urlString else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                imageView(image)
            } else if let loaded {
                imageView(loaded)
            } else {
                placeholder
            }
        }
        .clipped()
        .task(id: urlString) { await load() }
    }

    private func imageView(_ ui: UIImage) -> some View {
        Image(uiImage: ui)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }

    private func load() async {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            loaded = cached
            return
        }
        guard let (bytes, _) = try? await URLSession.shared.data(from: url),
              let ui = UIImage(data: bytes) else { return }
        ImageCache.shared.insert(ui, for: url)
        loaded = ui
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [contentType.tint.opacity(0.85), contentType.tint.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: contentType.systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

/// Small circular favicon with graceful fallback to the platform glyph.
struct FaviconView: View {
    let urlString: String?
    var platform: SourcePlatform?
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(Color.stashMuted.opacity(0.25))
            .overlay {
                Image(systemName: platform?.systemImage ?? "globe")
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(Color.stashMuted)
            }
    }
}
