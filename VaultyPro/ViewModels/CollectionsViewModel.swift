import SwiftUI
import SwiftData

@MainActor
@Observable
final class CollectionsViewModel {
    var showingNewCollection = false
    var renameTarget: Collection?
    var draftName = ""
    var draftEmoji = "📁"

    let emojiChoices = ["📁", "📚", "💡", "🍳", "🎬", "🎧", "✈️", "💼", "🏋️", "🎨", "🧠", "⭐️"]

    func createCollection(in context: ModelContext, existingCount: Int) {
        let name = draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let collection = Collection(name: name, emoji: draftEmoji,
                                    colorHex: "#F4A261", sortOrder: existingCount)
        context.insert(collection)
        try? context.save()
        reset()
    }

    func rename(in context: ModelContext) {
        guard let renameTarget else { return }
        let name = draftName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { renameTarget.name = name }
        renameTarget.emoji = draftEmoji
        try? context.save()
        reset()
    }

    func delete(_ collection: Collection, in context: ModelContext) {
        context.delete(collection)
        try? context.save()
    }

    func beginRename(_ collection: Collection) {
        renameTarget = collection
        draftName = collection.name
        draftEmoji = collection.emoji
    }

    private func reset() {
        showingNewCollection = false
        renameTarget = nil
        draftName = ""
        draftEmoji = "📁"
    }
}
