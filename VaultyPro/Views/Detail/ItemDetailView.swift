import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: StashItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(UndoCenter.self) private var undo
    @State private var model = DetailViewModel()
    @State private var showMove = false
    @State private var showNoteEditor = false
    @State private var noteDraft = ""
    @State private var noteSwipe: CGFloat = 0

    private var isArticle: Bool { item.contentType == .article && !model.paragraphs.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                media
                headerBlock
                if isArticle {
                    ArticleReaderView(item: item, model: model)
                }
                highlightsSection
                noteSection
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 8)
        }
        .background((isArticle ? model.background.color : Color.stashBackground).ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isArticle {
                    Button { model.showReaderSettings = true } label: {
                        Image(systemName: "textformat.size")
                    }.tint(Color.stashAmber)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { ItemActions.toggleFavorite(item, in: context) } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }.tint(Color.stashAmber)
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sheet(isPresented: $model.showReaderSettings) { ReaderSettingsSheet(model: model) }
        .sheet(isPresented: $showMove) { CollectionPickerSheet(item: item) }
        .sheet(isPresented: $showNoteEditor) { noteEditor }
        .task {
            model.loadContent(for: item)
            if item.readingProgress < 1 { /* could track scroll */ }
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var media: some View {
        switch item.contentType {
        case .video:
            // Only YouTube (and friends) can be embedded in the web player. For sources
            // we can't embed (e.g. X), the tweet page would just render black — so show
            // the poster image instead and let the user open the source to watch.
            if let url = item.url, Self.isEmbeddableVideo(url) {
                VideoPlayerView(urlString: url)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
            } else {
                posterMedia(showPlay: true)
            }
        case .image:
            ImageZoomView(data: item.thumbnailData, urlString: item.thumbnailURL ?? item.url)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 420)
                .background(Color.stashCardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppMetrics.cornerRadius)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
        case .audio:
            AudioBarView(item: item)
        case .article, .link, .note:
            if item.contentType != .note, item.thumbnailData != nil || item.thumbnailURL != nil {
                posterMedia(showPlay: false)
            }
        }
    }

    /// Aspect-preserving media well: fits the image inside a max-height box (never
    /// cropping or stretching) on a subtle surface so portrait and landscape both look right.
    private func posterMedia(showPlay: Bool) -> some View {
        ThumbnailView(data: item.thumbnailData, urlString: item.thumbnailURL,
                      contentType: item.contentType, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 380)
            .background(Color.stashCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadius)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .overlay {
                if showPlay, let urlString = item.url, let url = URL(string: urlString) {
                    Button { openURL(url) } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.stashNavy)
                            .frame(width: 60, height: 60)
                            .background(.white.opacity(0.95), in: Circle())
                            .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
    }

    private static func isEmbeddableVideo(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return MetadataFetcher.youTubeVideoID(url) != nil
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                FaviconView(urlString: item.faviconURL, platform: item.platform, size: 18)
                Text(item.sourceDomain ?? item.platform?.displayName ?? "Note")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                TypeBadgeView(type: item.contentType)
            }
            Text(item.displayTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(isArticle ? model.background.textColor : .primary)
            HStack(spacing: 10) {
                Text(item.savedAt.relativeLong).font(AppFont.metadata()).foregroundStyle(.secondary)
                if let m = item.estimatedReadTime, item.contentType == .article {
                    Text("· \(m) min read").font(AppFont.metadata()).foregroundStyle(Color.stashAmber)
                }
            }
            if let desc = item.itemDescription, !desc.isEmpty, !isArticle, item.contentType != .note {
                FormattedBody(text: desc, baseSize: 15.5, color: .primary.opacity(0.85))
                    .padding(.top, 2)
            }
            if item.contentType == .note, let body = item.itemDescription, !body.isEmpty {
                FormattedBody(text: body, baseSize: 17, color: .primary)
                    .padding(.top, 4)
            }
            if !item.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.tags, id: \.self) { TagChipView(text: $0) }
                }.padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var highlightsSection: some View {
        let highlights = item.sortedHighlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Highlights", systemImage: "highlighter").font(AppFont.sectionHeader())
                ForEach(highlights) { highlight in
                    Text(highlight.text)
                        .font(.system(size: 14))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: highlight.colorHex).opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private var noteSection: some View {
        let hasNote = item.userNote?.isEmpty == false
        VStack(alignment: .leading, spacing: 8) {
            Label("My Note", systemImage: "note.text").font(AppFont.sectionHeader())
            if hasNote {
                ZStack(alignment: .trailing) {
                    // Revealed behind the card when swiped left.
                    Button(role: .destructive) { removeNote() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "trash").font(.system(size: 17, weight: .semibold))
                            Text("Remove").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 76)
                        .frame(maxHeight: .infinity)
                        .background(Color.stashRed)
                    }
                    .buttonStyle(.plain)

                    noteCard(text: item.userNote ?? "", placeholder: false)
                        .offset(x: noteSwipe)
                        .gesture(noteDrag)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                noteCard(text: "Add a note…", placeholder: true)
            }
        }
    }

    private func noteCard(text: String, placeholder: Bool) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(placeholder ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            .onTapGesture {
                if noteSwipe != 0 {
                    withAnimation(.snappy(duration: 0.25)) { noteSwipe = 0 }
                } else {
                    noteDraft = item.userNote ?? ""
                    showNoteEditor = true
                }
            }
    }

    private var noteDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if value.translation.width < 0 {
                    noteSwipe = max(value.translation.width, -84)
                } else if noteSwipe < 0 {
                    noteSwipe = min(0, -84 + value.translation.width)
                }
            }
            .onEnded { value in
                withAnimation(.snappy(duration: 0.25)) {
                    noteSwipe = value.translation.width < -40 ? -84 : 0
                }
            }
    }

    private func removeNote() {
        withAnimation(.snappy(duration: 0.25)) { noteSwipe = 0 }
        item.userNote = nil
        try? context.save()
    }

    private var noteEditor: some View {
        NavigationStack {
            TextEditor(text: $noteDraft)
                .font(.system(size: 16)).padding()
                .background(Color.stashBackground.ignoresSafeArea())
                .navigationTitle("Note").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showNoteEditor = false }.tint(Color.stashAmber)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            item.userNote = noteDraft; try? context.save(); showNoteEditor = false
                        }.tint(Color.stashAmber).fontWeight(.semibold)
                    }
                }
        }.presentationDetents([.medium, .large])
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 2) {
            if let urlString = item.url, let url = URL(string: urlString) {
                ShareLink(item: url) { barItem("square.and.arrow.up", "Share") }
                    .frame(maxWidth: .infinity)
                barButton("safari", "Open") { openURL(url) }
                barButton("doc.on.doc", "Copy") { UIPasteboard.general.string = urlString }
            }
            barButton("folder.badge.plus", "Save") { showMove = true }
            barButton("archivebox", "Archive") { ItemActions.archive(item, in: context); dismiss() }
            barButton("trash", "Delete", tint: .stashRed) { ItemActions.delete(item, in: context, undo: undo); dismiss() }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.bottom, 6)
    }

    private func barButton(_ icon: String, _ label: String, tint: Color = .stashAmber,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) { barItem(icon, label, tint: tint) }
            .frame(maxWidth: .infinity)
    }

    private func barItem(_ icon: String, _ label: String, tint: Color = .stashAmber) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium))
            Text(label).font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
    }
}

/// Renders an arbitrary fetched body/caption (from any platform) as readable, well-spaced
/// content instead of one dense block: paragraphs are separated by blank lines, bullet
/// markers are normalized, and short standalone lines read as section headings.
struct FormattedBody: View {
    let text: String
    var baseSize: CGFloat = 15.5
    var color: Color = .primary

    private struct Block: Identifiable {
        let id = UUID()
        let lines: [String]
        let isHeading: Bool
    }

    private var blocks: [Block] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        // Collapse 3+ blank lines, then split into paragraphs on blank lines.
        return normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                let rawLines = paragraph
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let lines = rawLines.map(Self.cleanLine)
                let isHeading = lines.count == 1
                    && lines[0].count <= 32
                    && !lines[0].hasSuffix(".")
                    && !lines[0].hasPrefix("•")
                return Block(lines: lines, isHeading: isHeading)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                if block.isHeading {
                    Text(block.lines[0])
                        .font(.system(size: baseSize + 2.5, weight: .bold))
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(block.lines.joined(separator: "\n"))
                        .font(.system(size: baseSize))
                        .lineSpacing(4)
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Normalizes common markdown-ish list markers to a clean bullet.
    private static func cleanLine(_ line: String) -> String {
        for prefix in ["* ", "- ", "• "] where line.hasPrefix(prefix) {
            return "•  " + String(line.dropFirst(prefix.count))
        }
        return line
    }
}
