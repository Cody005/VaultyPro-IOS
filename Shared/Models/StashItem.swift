import Foundation
import SwiftData

@Model
final class StashItem {
    var id: UUID = UUID()
    var url: String?
    var title: String = ""
    var itemDescription: String?
    var thumbnailURL: String?
    @Attribute(.externalStorage) var thumbnailData: Data?   // cached locally
    var faviconURL: String?
    var sourceDomain: String?
    var contentTypeRaw: String = ContentType.link.rawValue
    var rawHTML: String?                                    // for article reader
    var fullText: String?                                   // stripped plain text for search
    var savedAt: Date = Date()
    var readAt: Date?
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var tags: [String] = []
    var userNote: String?
    var readingProgress: Double = 0.0                       // 0.0–1.0
    var estimatedReadTime: Int?                             // minutes
    var platformRaw: String?                                // instagram, twitter, youtube...

    @Relationship(deleteRule: .cascade, inverse: \Highlight.item)
    var highlights: [Highlight]? = []

    @Relationship(inverse: \Collection.items)
    var collection: Collection?

    init(
        id: UUID = UUID(),
        url: String? = nil,
        title: String = "",
        itemDescription: String? = nil,
        thumbnailURL: String? = nil,
        thumbnailData: Data? = nil,
        faviconURL: String? = nil,
        sourceDomain: String? = nil,
        contentType: ContentType = .link,
        rawHTML: String? = nil,
        fullText: String? = nil,
        savedAt: Date = Date(),
        readAt: Date? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        tags: [String] = [],
        userNote: String? = nil,
        readingProgress: Double = 0,
        estimatedReadTime: Int? = nil,
        platform: SourcePlatform? = nil,
        collection: Collection? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.itemDescription = itemDescription
        self.thumbnailURL = thumbnailURL
        self.thumbnailData = thumbnailData
        self.faviconURL = faviconURL
        self.sourceDomain = sourceDomain
        self.contentTypeRaw = contentType.rawValue
        self.rawHTML = rawHTML
        self.fullText = fullText
        self.savedAt = savedAt
        self.readAt = readAt
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.tags = tags
        self.userNote = userNote
        self.readingProgress = readingProgress
        self.estimatedReadTime = estimatedReadTime
        self.platformRaw = platform?.rawValue
        self.collection = collection
        self.highlights = []
    }
}

extension StashItem {
    var contentType: ContentType {
        get { ContentType(rawValue: contentTypeRaw) ?? .link }
        set { contentTypeRaw = newValue.rawValue }
    }

    var platform: SourcePlatform? {
        get { platformRaw.flatMap(SourcePlatform.init(rawValue:)) }
        set { platformRaw = newValue?.rawValue }
    }

    var isRead: Bool { readAt != nil }

    var displayTitle: String {
        title.isEmpty ? (sourceDomain ?? url ?? "Untitled") : title
    }

    var sortedHighlights: [Highlight] {
        (highlights ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}
