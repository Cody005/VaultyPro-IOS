import Foundation
import SwiftData

@Model
final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "📁"
    var colorHex: String = "#F4A261"
    var createdAt: Date = Date()
    var isSmart: Bool = false
    var smartFilter: String?            // identifier for smart collections
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify)
    var items: [StashItem]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        emoji: String = "📁",
        colorHex: String = "#F4A261",
        createdAt: Date = Date(),
        isSmart: Bool = false,
        smartFilter: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isSmart = isSmart
        self.smartFilter = smartFilter
        self.sortOrder = sortOrder
        self.items = []
    }
}

extension Collection {
    var itemCount: Int { (items ?? []).count }

    /// Up to four latest thumbnails for the cover mosaic.
    var coverThumbnails: [StashItem] {
        (items ?? [])
            .sorted { $0.savedAt > $1.savedAt }
            .prefix(4)
            .map { $0 }
    }
}

/// Built-in smart collection definitions surfaced automatically.
enum SmartCollection: String, CaseIterable, Identifiable {
    case unread, videos, articles, today, favorites

    var id: String { rawValue }

    var name: String {
        switch self {
        case .unread:    return "Unread"
        case .videos:    return "Videos"
        case .articles:  return "Articles"
        case .today:     return "Saved Today"
        case .favorites: return "Favorites"
        }
    }

    var emoji: String {
        switch self {
        case .unread:    return "📥"
        case .videos:    return "🎬"
        case .articles:  return "📰"
        case .today:     return "✨"
        case .favorites: return "⭐️"
        }
    }

    var colorHex: String {
        switch self {
        case .unread:    return "#F4A261"
        case .videos:    return "#FF6B6B"
        case .articles:  return "#4ECDC4"
        case .today:     return "#C77DFF"
        case .favorites: return "#52B788"
        }
    }

    func matches(_ item: StashItem) -> Bool {
        guard !item.isArchived else { return false }
        switch self {
        case .unread:    return !item.isRead
        case .videos:    return item.contentType == .video
        case .articles:  return item.contentType == .article
        case .today:     return Calendar.current.isDateInToday(item.savedAt)
        case .favorites: return item.isFavorite
        }
    }
}
