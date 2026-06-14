import Foundation
import SwiftData
import justhtml

/// Parses third-party export files into draft `StashItem`s.
enum ImportService {
    enum Source {
        case raindrop   // JSON
        case instapaper // HTML
        case pinboard   // XML / JSON
    }

    struct ParsedItem: Sendable {
        var url: String?
        var title: String
        var note: String?
        var tags: [String]
        var savedAt: Date
    }

    static func parse(data: Data, source: Source) -> [ParsedItem] {
        switch source {
        case .raindrop:   return parseRaindrop(data)
        case .instapaper: return parseInstapaper(data)
        case .pinboard:   return parsePinboard(data)
        }
    }

    @MainActor
    @discardableResult
    static func importItems(_ items: [ParsedItem], into context: ModelContext) -> Int {
        for parsed in items {
            let url = parsed.url
            let domain = url?.normalizedURL?.prettyDomain
            let item = StashItem(
                url: url,
                title: parsed.title.isEmpty ? (domain ?? "Imported") : parsed.title,
                faviconURL: domain.flatMap { "https://www.google.com/s2/favicons?sz=64&domain=\($0)" },
                sourceDomain: domain,
                contentType: url == nil ? .note : .link,
                savedAt: parsed.savedAt,
                tags: parsed.tags,
                userNote: parsed.note
            )
            context.insert(item)
        }
        try? context.save()
        return items.count
    }

    // MARK: - Raindrop.io (JSON export)

    private static func parseRaindrop(_ data: Data) -> [ParsedItem] {
        struct Root: Decodable { let items: [Raindrop]? }
        struct Raindrop: Decodable {
            let link: String?
            let title: String?
            let excerpt: String?
            let tags: [String]?
            let created: String?
        }

        let decoder = JSONDecoder()
        let raindrops: [Raindrop]
        if let root = try? decoder.decode(Root.self, from: data), let items = root.items {
            raindrops = items
        } else if let array = try? decoder.decode([Raindrop].self, from: data) {
            raindrops = array
        } else {
            return []
        }

        let iso = ISO8601DateFormatter()
        return raindrops.map { r in
            ParsedItem(
                url: r.link,
                title: r.title ?? "",
                note: r.excerpt,
                tags: r.tags ?? [],
                savedAt: r.created.flatMap { iso.date(from: $0) } ?? Date()
            )
        }
    }

    // MARK: - Instapaper (HTML export)

    private static func parseInstapaper(_ data: Data) -> [ParsedItem] {
        guard let html = String(data: data, encoding: .utf8),
              let doc = try? JustHTML(html),
              let links = try? doc.query("a[href]") else { return [] }
        return links.compactMap { a in
            let href = a.attrs["href"] ?? ""
            let title = a.toText().trimmingCharacters(in: .whitespacesAndNewlines)
            guard href.hasPrefix("http") else { return nil }
            return ParsedItem(url: href, title: title, note: nil, tags: [], savedAt: Date())
        }
    }

    // MARK: - Pinboard (XML or JSON export)

    private static func parsePinboard(_ data: Data) -> [ParsedItem] {
        // Try JSON first.
        struct Post: Decodable {
            let href: String?
            let description: String?
            let extended: String?
            let tags: String?
            let time: String?
        }
        if let posts = try? JSONDecoder().decode([Post].self, from: data) {
            let iso = ISO8601DateFormatter()
            return posts.map { p in
                ParsedItem(
                    url: p.href,
                    title: p.description ?? "",
                    note: p.extended,
                    tags: (p.tags ?? "").split(separator: " ").map(String.init),
                    savedAt: p.time.flatMap { iso.date(from: $0) } ?? Date()
                )
            }
        }
        // Fall back to XML.
        let parser = PinboardXMLParser()
        return parser.parse(data)
    }
}

/// Minimal XML parser for Pinboard's `<post .../>` format.
private final class PinboardXMLParser: NSObject, XMLParserDelegate {
    private var items: [ImportService.ParsedItem] = []

    func parse(_ data: Data) -> [ImportService.ParsedItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        guard elementName == "post" else { return }
        let iso = ISO8601DateFormatter()
        items.append(.init(
            url: attributeDict["href"],
            title: attributeDict["description"] ?? "",
            note: attributeDict["extended"],
            tags: (attributeDict["tag"] ?? "").split(separator: " ").map(String.init),
            savedAt: attributeDict["time"].flatMap { iso.date(from: $0) } ?? Date()
        ))
    }
}
