import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProStatusManager.self) private var pro
    @Query private var items: [StashItem]
    @State private var sync = CloudKitSyncMonitor()

    @AppStorage("appearancePreference") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("appIconChoice") private var appIconChoice = "default"

    @State private var showPaywall = false
    @State private var importing = false
    @State private var importSource: ImportService.Source = .raindrop
    @State private var exportURL: URL?
    @State private var importMessage: String?

    private var totalBytes: Int {
        items.reduce(0) { $0 + ($1.thumbnailData?.count ?? 0) + ($1.fullText?.utf8.count ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ScreenHeader("Profile")
                        .padding(.horizontal, -AppMetrics.hPadding)
                    subscriptionCard
                    syncCard
                    archiveCard
                    storageCard
                    appearanceCard
                    appIconCard
                    importExportCard
                    aboutCard
                    #if DEBUG
                    debugCard
                    #endif
                }
                .padding(AppMetrics.hPadding)
            }
            .background(AppBackground())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.json, .html, .xml, .plainText],
                          allowsMultipleSelection: false) { handleImport($0) }
            .alert("Import", isPresented: .constant(importMessage != nil)) {
                Button("OK") { importMessage = nil }
            } message: { Text(importMessage ?? "") }
        }
    }

    // MARK: - Cards

    private var subscriptionCard: some View {
        card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pro.isPro ? "VaultyPro Pro" : "VaultyPro Free")
                        .font(.system(size: 18, weight: .bold))
                    Text(pro.isPro ? "All features unlocked" : "\(items.count)/\(AppConfig.Free.maxItems) saves used")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                if !pro.isPro {
                    Button("Upgrade") { showPaywall = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.stashNavy)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Color.stashAmber, in: Capsule())
                } else {
                    Image(systemName: "crown.fill").foregroundStyle(Color.stashAmber).font(.title2)
                }
            }
        }
    }

    private var syncCard: some View {
        card {
            sectionTitle("iCloud")
            HStack {
                Image(systemName: sync.status.systemImage).foregroundStyle(Color.stashAmber)
                Text(sync.status.label)
                Spacer()
                if let last = sync.lastSync {
                    Text(last.relativeShort).font(AppFont.metadata()).foregroundStyle(.secondary)
                }
                Button { sync.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .tint(Color.stashAmber)
            }
            .font(.system(size: 15))
        }
    }

    private var archivedCount: Int { items.filter { $0.isArchived }.count }

    private var archiveCard: some View {
        NavigationLink {
            ArchiveView()
        } label: {
            card {
                HStack(spacing: 12) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(Color.stashAmber)
                        .font(.system(size: 17))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Archive").font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                        Text("Items you've cleared from your inbox")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(archivedCount)").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var storageCard: some View {
        card {
            sectionTitle("Storage")
            ForEach(ContentType.allCases) { type in
                let count = items.filter { $0.contentType == type }.count
                if count > 0 {
                    HStack {
                        Circle().fill(type.tint).frame(width: 8, height: 8)
                        Text(type.pluralTitle).font(.system(size: 14))
                        Spacer()
                        Text("\(count)").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
            }
            Divider().padding(.vertical, 2)
            HStack {
                Text("Cached media").font(.system(size: 14))
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceCard: some View {
        card {
            sectionTitle("Appearance")
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var appIconCard: some View {
        card {
            sectionTitle("App Icon")
            HStack(spacing: 16) {
                iconSwatch("default", colors: [.stashAmber, .stashRed])
                iconSwatch("AppIcon-Navy", colors: [.stashNavy, .typeArticle])
                iconSwatch("AppIcon-Violet", colors: [.typeImage, .stashAmber])
            }
        }
    }

    private var importExportCard: some View {
        card {
            sectionTitle("Import & Export")
            if !pro.isPro {
                Button { showPaywall = true } label: {
                    Label("Import / Export is a Pro feature", systemImage: "lock.fill")
                        .font(.system(size: 14)).foregroundStyle(Color.stashAmber)
                }
            } else {
                Menu {
                    Button("Raindrop.io (JSON)") { importSource = .raindrop; importing = true }
                    Button("Instapaper (HTML)") { importSource = .instapaper; importing = true }
                    Button("Pinboard (XML/JSON)") { importSource = .pinboard; importing = true }
                } label: {
                    Label("Import from…", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15))
                }
                .tint(Color.stashAmber)

                Divider().padding(.vertical, 2)

                Button { exportJSON() } label: {
                    Label("Export as JSON", systemImage: "square.and.arrow.up").font(.system(size: 15))
                }.tint(Color.stashAmber)
                Button { exportCSV() } label: {
                    Label("Export as CSV", systemImage: "tablecells").font(.system(size: 15))
                }.tint(Color.stashAmber)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share export file", systemImage: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.stashGreen)
                    }
                }
            }
        }
    }

    #if DEBUG
    private var debugCard: some View {
        card {
            sectionTitle("Developer")
            Toggle(isOn: Binding(get: { pro.debugProUnlocked },
                                 set: { pro.debugProUnlocked = $0 })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Pro").font(.system(size: 14, weight: .medium))
                    Text("Testing only · not in App Store builds")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .tint(Color.stashAmber)
        }
    }
    #endif

    private var aboutCard: some View {
        card {
            sectionTitle("About")
            HStack { Text("Version").font(.system(size: 14)); Spacer()
                Text("1.0").foregroundStyle(.secondary).font(.system(size: 14)) }
            HStack { Text("Made with").font(.system(size: 14)); Spacer()
                Text("SwiftUI · iOS 26").foregroundStyle(.secondary).font(.system(size: 14)) }
        }
    }

    // MARK: - Helpers

    private func iconSwatch(_ name: String, colors: [Color]) -> some View {
        Button { setIcon(name) } label: {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: "tray.full.fill").foregroundStyle(.white))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(appIconChoice == name ? Color.stashAmber : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    private func setIcon(_ name: String) {
        if !pro.isPro { showPaywall = true; return }
        appIconChoice = name
        let iconName: String? = name == "default" ? nil : name
        UIApplication.shared.setAlternateIconName(iconName) { _ in }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { importMessage = "Couldn't read file."; return }
        let parsed = ImportService.parse(data: data, source: importSource)
        let count = ImportService.importItems(parsed, into: context)
        importMessage = count > 0 ? "Imported \(count) item\(count == 1 ? "" : "s")." : "No items found in file."
    }

    private func exportJSON() {
        let data = ExportService.jsonData(ExportService.makeExportItems(items))
        exportURL = ExportService.writeTemp(data, filename: "vaultypro-export.json")
    }

    private func exportCSV() {
        let data = ExportService.csvData(ExportService.makeExportItems(items))
        exportURL = ExportService.writeTemp(data, filename: "vaultypro-export.csv")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(AppFont.sectionHeader()).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius).strokeBorder(Color.primary.opacity(0.05)))
    }
}

/// Lists archived items and lets the user restore them or delete them for good.
struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<StashItem> { $0.isArchived },
           sort: \StashItem.savedAt, order: .reverse)
    private var archived: [StashItem]

    var body: some View {
        Group {
            if archived.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: "Nothing archived",
                    message: "Swipe a card and tap Archive to tuck it away here without deleting it."
                )
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    ForEach(archived) { item in
                        NavigationLink(value: item) {
                            StashRowView(item: item)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: AppMetrics.hPadding, bottom: 5, trailing: AppMetrics.hPadding))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                ItemActions.delete(item, in: context, undo: undo)
                            } label: { Label("Delete", systemImage: "trash") }
                            Button {
                                withAnimation { ItemActions.unarchive(item, in: context) }
                            } label: { Label("Restore", systemImage: "tray.and.arrow.up.fill") }
                            .tint(Color.stashGreen)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppBackground())
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: StashItem.self) { ItemDetailView(item: $0) }
    }
}
