import SwiftUI

/// Create or rename a collection with an emoji picker.
struct CollectionEditorSheet: View {
    @Bindable var model: CollectionsViewModel
    let isRename: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let grid = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Collection name", text: $model.draftName)
                    .font(.system(size: 18, weight: .medium))
                    .padding(14)
                    .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 16))

                Text("Icon").font(AppFont.sectionHeader())
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(model.emojiChoices, id: \.self) { emoji in
                        Button { model.draftEmoji = emoji } label: {
                            Text(emoji).font(.system(size: 26))
                                .frame(width: 46, height: 46)
                                .background(
                                    Circle().fill(model.draftEmoji == emoji
                                                  ? Color.stashAmber.opacity(0.3) : Color.stashCardSurface)
                                )
                                .overlay(Circle().strokeBorder(model.draftEmoji == emoji
                                                               ? Color.stashAmber : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(AppMetrics.hPadding)
            .background(Color.stashBackground.ignoresSafeArea())
            .navigationTitle(isRename ? "Edit Collection" : "New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.stashAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRename ? "Save" : "Create") { onSave() }
                        .tint(Color.stashAmber).fontWeight(.semibold)
                        .disabled(model.draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
