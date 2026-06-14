import SwiftUI
import SwiftData

/// Owns the shared SwiftData container and presents the save sheet.
struct ShareRootView: View {
    let input: SharedInput
    let onClose: () -> Void

    private let container = Persistence.makeContainer()

    var body: some View {
        ShareSheetView(input: input, onClose: onClose)
            .modelContainer(container)
    }
}

struct ShareSheetView: View {
    let input: SharedInput
    let onClose: () -> Void

    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var thumbnailData: Data?
    @State private var thumbnailURL: String?
    @State private var contentType: ContentType = .link
    @State private var domain: String?
    @State private var faviconURL: String?
    @State private var platform: SourcePlatform?
    /// Set when shared plain text contained a link we resolved into a card.
    @State private var resolvedURL: String?

    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var existingTags: [String] = []
    @State private var collections: [Collection] = []
    @State private var selectedCollection: Collection?

    @State private var loading = true
    @State private var saving = false
    @State private var appear = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appear ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            sheet
                .offset(y: appear ? 0 : 600)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appear)
        .task {
            appear = true
            loadExistingMetadata()
            await prefill()
        }
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.stashMuted.opacity(0.5)).frame(width: 40, height: 5).padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    thumbnail
                    titleField
                    tagSection
                    collectionSection
                }
                .padding(20)
            }
            .frame(maxHeight: 520)

            saveButton
        }
        .background(Color.stashBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
        .shadow(color: .black.opacity(0.3), radius: 20, y: -4)
    }

    private var header: some View {
        HStack {
            Label("Save to VaultyPro", systemImage: "tray.full.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.stashAmber)
            Spacer()
            Button { close() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            ThumbnailView(data: thumbnailData, urlString: thumbnailURL, contentType: contentType)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    TypeBadgeView(type: contentType).padding(8)
                }
            if loading {
                RoundedRectangle(cornerRadius: 16).fill(Color.stashMuted.opacity(0.2))
                    .frame(height: 150).shimmering()
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title").font(AppFont.metadata()).foregroundStyle(.secondary)
            TextField("Title", text: $title, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 16, weight: .medium))
                .padding(12)
                .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 12))
            if let domain {
                HStack(spacing: 5) {
                    FaviconView(urlString: faviconURL, platform: platform, size: 14)
                    Text(domain).font(AppFont.metadata()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(AppFont.metadata()).foregroundStyle(.secondary)
            HStack {
                TextField("Add tag…", text: $newTag)
                    .textInputAutocapitalization(.never)
                    .onSubmit(addTag)
                Button(action: addTag) { Image(systemName: "plus.circle.fill") }
                    .tint(Color.stashAmber).disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
            .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 12))

            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChipView(text: tag, isSelected: true,
                                    onRemove: { tags.removeAll { $0 == tag } })
                    }
                }
            }
            if !existingTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(existingTags.filter { !tags.contains($0) }.prefix(8), id: \.self) { tag in
                        Button { tags.append(tag) } label: { TagChipView(text: tag) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection").font(AppFont.metadata()).foregroundStyle(.secondary)
            Menu {
                Button("None") { selectedCollection = nil }
                ForEach(collections) { collection in
                    Button("\(collection.emoji) \(collection.name)") { selectedCollection = collection }
                }
            } label: {
                HStack {
                    Text(selectedCollection.map { "\($0.emoji) \($0.name)" } ?? "None")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary).font(.caption)
                }
                .padding(12)
                .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                if saving { ProgressView().tint(.stashNavy) }
                Text(saving ? "Saving…" : "Save")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Color.stashNavy)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Color.stashAmber.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(saving)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .padding(.top, 6)
    }

    // MARK: - Logic

    private func loadExistingMetadata() {
        if let fetched = try? context.fetch(FetchDescriptor<Collection>(
            predicate: #Predicate { !$0.isSmart },
            sortBy: [SortDescriptor(\.sortOrder)])) {
            collections = fetched
        }
        if let items = try? context.fetch(FetchDescriptor<StashItem>()) {
            existingTags = Array(Set(items.flatMap(\.tags))).sorted()
        }
    }

    private func prefill() async {
        switch input {
        case .url(let raw):
            await prefillURL(raw)
        case .text(let text):
            // A link wrapped in shared copy (LinkedIn, etc.) should fetch a card.
            if let url = text.firstDetectedURL {
                resolvedURL = url.absoluteString
                await prefillURL(url.absoluteString)
            } else {
                contentType = .note
                title = String(text.split(separator: "\n").first.map(String.init)?.prefix(80) ?? "Note")
            }
        case .image(let data):
            contentType = .image
            thumbnailData = data
            title = "Image"
        }
        loading = false
    }

    private func prefillURL(_ raw: String) async {
        title = raw.normalizedURL?.prettyDomain ?? raw
        let meta = await MetadataFetcher.shared.fetch(urlString: raw)
        title = meta.title ?? title
        thumbnailURL = meta.imageURL
        contentType = meta.contentType
        domain = meta.sourceDomain
        faviconURL = meta.faviconURL
        platform = meta.platform
        thumbnailData = await MetadataFetcher.shared.downloadImageData(from: meta.imageURL)
    }

    private func addTag() {
        let clean = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty, !tags.contains(clean) else { return }
        tags.append(clean)
        newTag = ""
    }

    private func save() {
        saving = true
        let item: StashItem
        switch input {
        case .url(let raw):
            item = StashItem(url: raw.normalizedURL?.absoluteString ?? raw, title: title,
                             thumbnailURL: thumbnailURL, thumbnailData: thumbnailData,
                             faviconURL: faviconURL, sourceDomain: domain,
                             contentType: contentType, tags: tags, platform: platform)
        case .text(let text):
            if let resolvedURL {
                item = StashItem(url: resolvedURL.normalizedURL?.absoluteString ?? resolvedURL,
                                 title: title, thumbnailURL: thumbnailURL, thumbnailData: thumbnailData,
                                 faviconURL: faviconURL, sourceDomain: domain,
                                 contentType: contentType, tags: tags, platform: platform)
            } else {
                item = StashItem(title: title, itemDescription: text, contentType: .note,
                                 fullText: text, tags: tags)
            }
        case .image:
            item = StashItem(title: title, thumbnailData: thumbnailData,
                             contentType: .image, tags: tags)
        }
        item.collection = selectedCollection
        context.insert(item)
        try? context.save()
        close()
    }

    private func close() {
        appear = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onClose() }
    }
}
