import Foundation
import justhtml

/// Converts raw HTML into clean, readable paragraphs for the article reader.
enum ContentParser {

    struct ReadableContent: Sendable {
        var paragraphs: [String]
        var plainText: String
        var estimatedReadTime: Int
    }

    /// Block-level tags we surface as readable paragraphs, in document order.
    private static let blockTags: Set<TagID> = [.p, .h1, .h2, .h3, .h4, .li, .blockquote, .pre]

    /// Containers we strip before extracting readable content.
    private static let junkSelectors = ["script", "style", "nav", "header", "footer", "aside", "form", "noscript"]

    /// Extracts readable text from HTML, stripping nav/scripts/styles.
    static func parse(html: String) -> ReadableContent {
        guard let doc = try? JustHTML(html) else {
            return ReadableContent(paragraphs: [], plainText: "", estimatedReadTime: 1)
        }

        // Remove non-content containers from the tree.
        for selector in junkSelectors {
            for node in (try? doc.query(selector)) ?? [] {
                node.parent?.removeChild(node)
            }
        }

        // Prefer a semantic <article>, else fall back to <body>, else the root.
        let root = (try? doc.query("article"))?.first
            ?? (try? doc.query("body"))?.first
            ?? doc.root

        var paragraphs: [String] = []
        collectBlocks(root, into: &paragraphs)

        // Fallback: split the body's plain text if no block elements were found.
        if paragraphs.isEmpty {
            let bodyText = ((try? doc.query("body"))?.first ?? doc.root).toText()
            paragraphs = bodyText
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 1 }
        }

        let plain = paragraphs.joined(separator: "\n\n")
        let words = plain.split { $0 == " " || $0 == "\n" }.count
        return ReadableContent(paragraphs: paragraphs, plainText: plain, estimatedReadTime: max(1, words / 200))
    }

    /// Depth-first walk collecting text of block-level elements without descending into them.
    private static func collectBlocks(_ node: Node, into paragraphs: inout [String]) {
        for child in node.children {
            if Self.blockTags.contains(child.tagId) {
                let text = child.toText().trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 1 { paragraphs.append(text) }
            } else {
                collectBlocks(child, into: &paragraphs)
            }
        }
    }
}
