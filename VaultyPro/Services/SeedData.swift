import Foundation
import SwiftData

/// Seeds realistic demo content on first launch so no screen ever looks empty.
@MainActor
enum SeedData {
    private static let hasSeededKey = "vaultypro.hasSeeded.v1"

    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        let existing = (try? context.fetchCount(FetchDescriptor<StashItem>())) ?? 0
        guard !defaults.bool(forKey: hasSeededKey), existing == 0 else { return }

        let collections = makeCollections()
        collections.forEach { context.insert($0) }
        let readLater = collections.first { $0.name == "Read Later" }
        let inspiration = collections.first { $0.name == "Inspiration" }

        for (offset, draft) in demoItems().enumerated() {
            let item = draft.makeItem()
            if offset % 3 == 0 { item.collection = readLater }
            else if offset % 3 == 1 { item.collection = inspiration }
            context.insert(item)
        }

        try? context.save()
        defaults.set(true, forKey: hasSeededKey)
    }

    private static func makeCollections() -> [Collection] {
        [
            Collection(name: "Read Later", emoji: "📚", colorHex: "#4ECDC4", sortOrder: 0),
            Collection(name: "Inspiration", emoji: "💡", colorHex: "#C77DFF", sortOrder: 1),
            Collection(name: "Recipes", emoji: "🍳", colorHex: "#F4A261", sortOrder: 2)
        ]
    }

    private struct Draft {
        var url: String?
        var title: String
        var desc: String?
        var thumb: String?
        var domain: String?
        var type: ContentType
        var platform: SourcePlatform
        var minutesAgo: Int
        var read: Bool = false
        var favorite: Bool = false
        var note: String? = nil
        var readTime: Int? = nil
        var tags: [String] = []

        func makeItem() -> StashItem {
            StashItem(
                url: url,
                title: title,
                itemDescription: desc,
                thumbnailURL: thumb,
                faviconURL: domain.flatMap { "https://www.google.com/s2/favicons?sz=64&domain=\($0)" },
                sourceDomain: domain,
                contentType: type,
                fullText: desc,
                savedAt: Calendar.current.date(byAdding: .minute, value: -minutesAgo, to: Date()) ?? Date(),
                readAt: read ? Date() : nil,
                isFavorite: favorite,
                tags: tags,
                userNote: note,
                estimatedReadTime: readTime,
                platform: platform
            )
        }
    }

    private static func demoItems() -> [Draft] {
        [
            Draft(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                  title: "The Design of Everyday Things — explained in 12 minutes",
                  desc: "A crisp walkthrough of Don Norman's principles applied to modern product design.",
                  thumb: "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
                  domain: "youtube.com", type: .video, platform: .youtube,
                  minutesAgo: 8, favorite: true, tags: ["design", "video"]),

            Draft(url: "https://www.nngroup.com/articles/ten-usability-heuristics/",
                  title: "10 Usability Heuristics for User Interface Design",
                  desc: "Jakob Nielsen's ten general principles for interaction design — timeless and practical.",
                  thumb: "https://picsum.photos/seed/heuristics/800/450",
                  domain: "nngroup.com", type: .article, platform: .other,
                  minutesAgo: 42, readTime: 9, tags: ["ux", "reading"]),

            Draft(url: "https://www.instagram.com/p/CxYzAbCdEfG/",
                  title: "Minimalist workspace setups that actually work",
                  desc: "Carousel of 8 desk setups with gear lists.",
                  thumb: "https://picsum.photos/seed/insta/800/800",
                  domain: "instagram.com", type: .link, platform: .instagram,
                  minutesAgo: 120, tags: ["setup"]),

            Draft(url: "https://x.com/paulg/status/1700000000000000000",
                  title: "Paul Graham on X: \"The best founders treat writing as thinking.\"",
                  desc: "A short thread on why clear writing compounds.",
                  thumb: "https://picsum.photos/seed/xpost/800/450",
                  domain: "x.com", type: .link, platform: .twitter,
                  minutesAgo: 200, read: true, tags: ["startups"]),

            Draft(url: "https://open.spotify.com/episode/abc123",
                  title: "Lenny's Podcast — Building product intuition",
                  desc: "How great PMs develop taste and judgement over time.",
                  thumb: "https://picsum.photos/seed/podcast/800/450",
                  domain: "open.spotify.com", type: .audio, platform: .spotify,
                  minutesAgo: 320, tags: ["product", "podcast"]),

            Draft(url: "https://picsum.photos/seed/mountain/1200/800",
                  title: "Reference: alpine color palette",
                  thumb: "https://picsum.photos/seed/mountain/800/600",
                  domain: "picsum.photos", type: .image, platform: .other,
                  minutesAgo: 480, favorite: true, tags: ["color", "reference"]),

            Draft(title: "Idea: a weekly digest email of everything I saved",
                  desc: "Idea: a weekly digest email of everything I saved\n\nGroup by collection, include thumbnails, one-tap archive.",
                  type: .note, platform: .other,
                  minutesAgo: 700, note: "Could ship as a Pro feature."),

            Draft(url: "https://www.tiktok.com/@chef/video/7300000000000000000",
                  title: "60-second weeknight pasta",
                  desc: "Garlic, chili, parmesan — done in one pan.",
                  thumb: "https://picsum.photos/seed/pasta/800/1200",
                  domain: "tiktok.com", type: .link, platform: .tiktok,
                  minutesAgo: 1500, tags: ["recipes"]),

            Draft(url: "https://www.swift.org/blog/swift-6/",
                  title: "Announcing Swift 6 — strict concurrency by default",
                  desc: "What strict concurrency means for your codebase and how to adopt it incrementally.",
                  thumb: "https://picsum.photos/seed/swift/800/450",
                  domain: "swift.org", type: .article, platform: .other,
                  minutesAgo: 2880, read: true, readTime: 7, tags: ["swift", "dev"]),

            Draft(url: "https://www.reddit.com/r/iosdev/comments/abc/liquid_glass_tips/",
                  title: "Liquid Glass tips that made my app feel native on iOS 26",
                  desc: "A community thread of do's and don'ts for the new material.",
                  thumb: "https://picsum.photos/seed/reddit/800/450",
                  domain: "reddit.com", type: .link, platform: .reddit,
                  minutesAgo: 4320, tags: ["ios", "design"])
        ]
    }
}
