import SwiftUI
import SwiftData

/// Sheet to move an item into a user collection (or remove it from one).
struct CollectionPickerSheet: View {
    let item: StashItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Collection> { !$0.isSmart },
           sort: \Collection.sortOrder) private var collections: [Collection]

    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(collections) { collection in
                        row(collection)
                    }

                    HStack {
                        TextField("New collection…", text: $newName)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                        Button {
                            createAndMove()
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        .tint(Color.stashAmber)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(AppMetrics.hPadding)
            }
            .background(Color.stashBackground.ignoresSafeArea())
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.tint(Color.stashAmber)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ collection: Collection) -> some View {
        Button {
            ItemActions.move(item, to: item.collection == collection ? nil : collection, in: context)
        } label: {
            HStack(spacing: 12) {
                Text(collection.emoji).font(.title3)
                Text(collection.name).font(.system(size: 16, weight: .medium))
                Spacer()
                if item.collection == collection {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.stashGreen)
                }
            }
            .foregroundStyle(.primary)
            .padding(14)
            .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func createAndMove() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let collection = Collection(name: name, emoji: "📁",
                                    colorHex: "#F4A261", sortOrder: collections.count)
        context.insert(collection)
        ItemActions.move(item, to: collection, in: context)
        newName = ""
    }
}
