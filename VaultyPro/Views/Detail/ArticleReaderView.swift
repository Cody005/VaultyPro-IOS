import SwiftUI
import SwiftData

/// Immersive article reader with adjustable typography and paragraph highlighting.
struct ArticleReaderView: View {
    let item: StashItem
    @Bindable var model: DetailViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: model.lineSpacing + 8) {
            ForEach(Array(model.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                paragraphView(paragraph)
            }
        }
        .padding(.horizontal, 4)
    }

    private func paragraphView(_ paragraph: String) -> some View {
        let highlight = (item.highlights ?? []).first { $0.text == paragraph }
        return Text(paragraph)
            .font(.system(size: model.fontSize, weight: .regular, design: model.font.design))
            .lineSpacing(model.lineSpacing)
            .foregroundStyle(model.background.textColor)
            .padding(.vertical, 2)
            .background(highlight.map { Color(hex: $0.colorHex).opacity(0.5) } ?? .clear)
            .contextMenu {
                if let highlight {
                    Button(role: .destructive) {
                        context.delete(highlight); try? context.save()
                    } label: { Label("Remove Highlight", systemImage: "highlighter") }
                } else {
                    ForEach(HighlightColor.allCases) { color in
                        Button { addHighlight(paragraph, color: color) } label: {
                            Label(color.rawValue.capitalized, systemImage: "highlighter")
                        }
                    }
                }
                Button { UIPasteboard.general.string = paragraph } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
    }

    private func addHighlight(_ text: String, color: HighlightColor) {
        let highlight = Highlight(text: text, colorHex: color.hex, item: item)
        context.insert(highlight)
        if item.highlights == nil { item.highlights = [] }
        item.highlights?.append(highlight)
        try? context.save()
    }
}
