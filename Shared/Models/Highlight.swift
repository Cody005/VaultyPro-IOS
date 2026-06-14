import Foundation
import SwiftData

@Model
final class Highlight {
    var id: UUID = UUID()
    var text: String = ""
    var colorHex: String = "#F4D35E"
    var createdAt: Date = Date()
    var item: StashItem?

    init(
        id: UUID = UUID(),
        text: String = "",
        colorHex: String = "#F4D35E",
        createdAt: Date = Date(),
        item: StashItem? = nil
    ) {
        self.id = id
        self.text = text
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.item = item
    }
}

/// The four highlight colors offered in the reader.
enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow, blue, green, pink

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .yellow: return "#F4D35E"
        case .blue:   return "#90C2E7"
        case .green:  return "#95D5B2"
        case .pink:   return "#F7A1C4"
        }
    }
}
