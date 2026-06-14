import Foundation
import SwiftData

/// A piece of content arriving from the share sheet or Quick Add.
enum SharedInput: Sendable {
    case url(String)
    case text(String)
    case image(Data)
}

/// Creates and enriches `StashItem`s from shared input. Used by the app and the extension.
@MainActor
enum ItemSaver {

    /// Inserts an item immediately with best-effort provisional data so the UI can show it at once.
    @discardableResult
    static func insertDraft(from input: SharedInput, into context: ModelContext) -> StashItem {
        let item: StashItem
        switch input {
        case .url(let raw):
            let url = raw.normalizedURL
            let platform = url.map { MetadataFetcher.detectPlatform($0) } ?? .other
            item = StashItem(
                url: url?.absoluteString ?? raw,
                title: url?.prettyDomain ?? raw,
                faviconURL: url?.faviconURL?.absoluteString,
                sourceDomain: url?.prettyDomain,
                contentType: .link,
                platform: platform
            )
        case .text(let text):
            // Social apps (LinkedIn, etc.) often share a link wrapped in descriptive
            // copy. Pull out the link and treat it as a link so we can fetch a card.
            if let url = text.firstDetectedURL {
                return insertDraft(from: .url(url.absoluteString), into: context)
            }
            let firstLine = text.split(separator: "\n").first.map(String.init) ?? "Note"
            item = StashItem(
                title: String(firstLine.prefix(80)),
                itemDescription: text,
                contentType: .note,
                fullText: text,
                platform: .other
            )
        case .image(let data):
            item = StashItem(
                title: "Image",
                thumbnailData: data,
                contentType: .image,
                platform: .other
            )
        }
        context.insert(item)
        try? context.save()
        return item
    }

    /// Fetches richer metadata for a URL-backed item and updates it in place.
    static func enrich(_ item: StashItem, in context: ModelContext) async {
        guard let urlString = item.url, item.contentType != .note else { return }
        let meta = await MetadataFetcher.shared.fetch(urlString: urlString)
        let imageData = await MetadataFetcher.shared.downloadImageData(from: meta.imageURL)

        if let title = meta.title, !title.isEmpty { item.title = title }
        item.itemDescription = meta.description ?? item.itemDescription
        item.thumbnailURL = meta.imageURL ?? item.thumbnailURL
        item.faviconURL = meta.faviconURL ?? item.faviconURL
        item.sourceDomain = meta.sourceDomain ?? item.sourceDomain
        item.contentType = meta.contentType
        item.platform = meta.platform
        item.fullText = meta.fullText ?? item.fullText
        item.rawHTML = meta.rawHTML ?? item.rawHTML
        item.estimatedReadTime = meta.estimatedReadTime ?? item.estimatedReadTime
        if let imageData { item.thumbnailData = imageData }
        try? context.save()
    }
}
