import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var typeFilter: ContentType?
    var unreadOnly = false
    var recents: [String] = []

    private let recentsKey = "vaultypro.recentSearches"

    init() {
        recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    func commitRecent() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 1 else { return }
        recents.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recents.insert(trimmed, at: 0)
        recents = Array(recents.prefix(8))
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    func clearRecents() {
        recents = []
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }

    func results(from items: [StashItem]) -> [StashItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { item in
            guard !item.isArchived, !item.isInVault else { return false }
            if let typeFilter, item.contentType != typeFilter { return false }
            if unreadOnly && item.isRead { return false }
            guard !q.isEmpty else { return true }
            return item.title.lowercased().contains(q)
                || (item.itemDescription?.lowercased().contains(q) ?? false)
                || (item.url?.lowercased().contains(q) ?? false)
                || (item.userNote?.lowercased().contains(q) ?? false)
                || item.tags.contains { $0.lowercased().contains(q) }
        }
        .sorted { $0.savedAt > $1.savedAt }
    }
}
