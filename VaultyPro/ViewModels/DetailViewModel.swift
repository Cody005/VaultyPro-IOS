import SwiftUI

enum ReaderFont: String, CaseIterable, Identifiable {
    case system, serif, mono
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var design: Font.Design {
        switch self {
        case .system: return .default
        case .serif:  return .serif
        case .mono:   return .monospaced
        }
    }
}

enum ReaderBackground: String, CaseIterable, Identifiable {
    case white, sepia, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .white: return Color(hex: "#FFFFFF")
        case .sepia: return Color(hex: "#F4ECD8")
        case .dark:  return Color(hex: "#15202B")
        }
    }
    var textColor: Color { self == .dark ? Color(hex: "#E6E9EC") : Color(hex: "#1C1C1E") }
}

/// Persisted reader appearance settings + per-item parsed content.
@MainActor
@Observable
final class DetailViewModel {
    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "reader.fontSize") }
    }
    var lineSpacing: Double {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: "reader.lineSpacing") }
    }
    var font: ReaderFont {
        didSet { UserDefaults.standard.set(font.rawValue, forKey: "reader.font") }
    }
    var background: ReaderBackground {
        didSet { UserDefaults.standard.set(background.rawValue, forKey: "reader.background") }
    }

    var paragraphs: [String] = []
    var showReaderSettings = false

    init() {
        let defaults = UserDefaults.standard
        fontSize = defaults.object(forKey: "reader.fontSize") as? Double ?? 18
        lineSpacing = defaults.object(forKey: "reader.lineSpacing") as? Double ?? 7
        font = ReaderFont(rawValue: defaults.string(forKey: "reader.font") ?? "") ?? .serif
        background = ReaderBackground(rawValue: defaults.string(forKey: "reader.background") ?? "") ?? .sepia
    }

    func loadContent(for item: StashItem) {
        if let html = item.rawHTML, !html.isEmpty {
            paragraphs = ContentParser.parse(html: html).paragraphs
        } else if let text = item.fullText ?? item.itemDescription {
            paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        } else {
            paragraphs = []
        }
    }
}
