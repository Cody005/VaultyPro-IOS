import Foundation

/// Serializes saved items to JSON or CSV for export/sharing.
enum ExportService {

    struct ExportItem: Codable {
        var title: String
        var url: String?
        var description: String?
        var type: String
        var tags: [String]
        var note: String?
        var isFavorite: Bool
        var isRead: Bool
        var savedAt: Date
    }

    @MainActor
    static func makeExportItems(_ items: [StashItem]) -> [ExportItem] {
        items.map { item in
            ExportItem(
                title: item.title,
                url: item.url,
                description: item.itemDescription,
                type: item.contentType.rawValue,
                tags: item.tags,
                note: item.userNote,
                isFavorite: item.isFavorite,
                isRead: item.isRead,
                savedAt: item.savedAt
            )
        }
    }

    static func jsonData(_ items: [ExportItem]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(items)) ?? Data()
    }

    static func csvData(_ items: [ExportItem]) -> Data {
        var rows = ["title,url,type,tags,favorite,read,savedAt"]
        let iso = ISO8601DateFormatter()
        for item in items {
            let fields = [
                item.title,
                item.url ?? "",
                item.type,
                item.tags.joined(separator: "|"),
                item.isFavorite ? "true" : "false",
                item.isRead ? "true" : "false",
                iso.string(from: item.savedAt)
            ].map(escapeCSV)
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    /// Writes data to a temporary file and returns its URL for the share sheet.
    static func writeTemp(_ data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
