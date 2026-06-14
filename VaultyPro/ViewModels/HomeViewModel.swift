import SwiftUI

enum LayoutMode: String, CaseIterable {
    case grid, list
    var systemImage: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

/// Filter for the Home inbox: "All" or a specific content type.
enum HomeFilter: Hashable, Identifiable, CaseIterable {
    case all
    case type(ContentType)

    static var allCases: [HomeFilter] { [.all] + ContentType.allCases.map { .type($0) } }

    var id: String {
        switch self {
        case .all: return "all"
        case .type(let t): return t.rawValue
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .type(let t): return t.pluralTitle
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .type(let t): return t.systemImage
        }
    }

    var tint: Color {
        switch self {
        case .all: return .stashAmber
        case .type(let t): return t.tint
        }
    }

    func matches(_ item: StashItem) -> Bool {
        switch self {
        case .all: return true
        case .type(let t): return item.contentType == t
        }
    }
}

@MainActor
@Observable
final class HomeViewModel {
    var filter: HomeFilter = .all
    var layout: LayoutMode = .grid
    var isRefreshing = false
    var showQuickAdd = false

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }

    func savedToday(_ items: [StashItem]) -> Int {
        items.filter { Calendar.current.isDateInToday($0.savedAt) }.count
    }

    func filtered(_ items: [StashItem]) -> [StashItem] {
        items
            .filter { !$0.isArchived && filter.matches($0) }
            .sorted { $0.savedAt > $1.savedAt }
    }
}
