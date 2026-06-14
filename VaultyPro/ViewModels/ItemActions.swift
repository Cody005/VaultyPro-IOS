import SwiftUI
import SwiftData

/// Centralized mutations applied to a `StashItem` from cards, rows and detail.
@MainActor
enum ItemActions {
    static func toggleRead(_ item: StashItem, in context: ModelContext) {
        item.readAt = item.isRead ? nil : Date()
        if item.isRead { item.readingProgress = max(item.readingProgress, 1) }
        save(context)
    }

    static func toggleFavorite(_ item: StashItem, in context: ModelContext) {
        item.isFavorite.toggle()
        save(context)
    }

    static func archive(_ item: StashItem, in context: ModelContext) {
        item.isArchived = true
        save(context)
    }

    static func unarchive(_ item: StashItem, in context: ModelContext) {
        item.isArchived = false
        save(context)
    }

    /// Permanently deletes an item. When an `UndoCenter` is provided, a snapshot is
    /// captured first so the deletion can be reversed from the undo toast.
    static func delete(_ item: StashItem, in context: ModelContext, undo: UndoCenter? = nil) {
        if let undo {
            undo.register(DeletedItemSnapshot(item), message: "Deleted “\(item.displayTitle)”")
        }
        context.delete(item)
        save(context)
    }

    static func move(_ item: StashItem, to collection: Collection?, in context: ModelContext) {
        item.collection = collection
        save(context)
    }

    static func addTag(_ tag: String, to item: StashItem, in context: ModelContext) {
        let clean = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty, !item.tags.contains(clean) else { return }
        item.tags.append(clean)
        save(context)
    }

    private static func save(_ context: ModelContext) {
        try? context.save()
    }
}

/// A value snapshot of a deleted item so a hard delete can be reversed.
/// Captures highlights and the owning collection as well so an undo restores them.
@MainActor
struct DeletedItemSnapshot {
    private let url: String?
    private let title: String
    private let itemDescription: String?
    private let thumbnailURL: String?
    private let thumbnailData: Data?
    private let faviconURL: String?
    private let sourceDomain: String?
    private let contentType: ContentType
    private let rawHTML: String?
    private let fullText: String?
    private let savedAt: Date
    private let readAt: Date?
    private let isFavorite: Bool
    private let isArchived: Bool
    private let tags: [String]
    private let userNote: String?
    private let readingProgress: Double
    private let estimatedReadTime: Int?
    private let platform: SourcePlatform?
    private let collection: Collection?
    private let highlights: [(text: String, colorHex: String, createdAt: Date)]

    init(_ item: StashItem) {
        url = item.url
        title = item.title
        itemDescription = item.itemDescription
        thumbnailURL = item.thumbnailURL
        thumbnailData = item.thumbnailData
        faviconURL = item.faviconURL
        sourceDomain = item.sourceDomain
        contentType = item.contentType
        rawHTML = item.rawHTML
        fullText = item.fullText
        savedAt = item.savedAt
        readAt = item.readAt
        isFavorite = item.isFavorite
        isArchived = item.isArchived
        tags = item.tags
        userNote = item.userNote
        readingProgress = item.readingProgress
        estimatedReadTime = item.estimatedReadTime
        platform = item.platform
        collection = item.collection
        highlights = (item.highlights ?? []).map { ($0.text, $0.colorHex, $0.createdAt) }
    }

    func restore(into context: ModelContext) {
        let item = StashItem(
            url: url, title: title, itemDescription: itemDescription,
            thumbnailURL: thumbnailURL, thumbnailData: thumbnailData,
            faviconURL: faviconURL, sourceDomain: sourceDomain,
            contentType: contentType, rawHTML: rawHTML, fullText: fullText,
            savedAt: savedAt, readAt: readAt, isFavorite: isFavorite,
            isArchived: isArchived, tags: tags, userNote: userNote,
            readingProgress: readingProgress, estimatedReadTime: estimatedReadTime,
            platform: platform, collection: collection
        )
        context.insert(item)
        for h in highlights {
            context.insert(Highlight(text: h.text, colorHex: h.colorHex, createdAt: h.createdAt, item: item))
        }
        try? context.save()
    }
}

/// Holds the most recently deleted item so the UI can offer a brief "Undo" window.
@MainActor
@Observable
final class UndoCenter {
    private(set) var pending: DeletedItemSnapshot?
    private(set) var message = ""
    private var dismissTask: Task<Void, Never>?

    /// Registers a deletion and starts the auto-dismiss countdown.
    func register(_ snapshot: DeletedItemSnapshot, message: String) {
        self.pending = snapshot
        self.message = message
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.pending = nil
        }
    }

    func undo(in context: ModelContext) {
        pending?.restore(into: context)
        clear()
    }

    func clear() {
        pending = nil
        dismissTask?.cancel()
        dismissTask = nil
    }
}
