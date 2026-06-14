import SwiftUI
import SwiftData

/// Sheet for manually pasting a URL or jotting a quick note.
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStatusManager.self) private var pro

    @State private var input: String = ""
    @State private var saving = false
    @State private var showPaywall = false

    @Query private var items: [StashItem]

    private var isURL: Bool { input.normalizedURL?.scheme != nil && input.contains(".") && !input.contains(" ") }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(isURL ? "Link" : input.isEmpty ? "Paste or type" : "Note",
                          systemImage: isURL ? "link" : "note.text")
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.stashAmber)

                    TextField("https://… or a quick note", text: $input, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.stashMuted.opacity(0.2)))

                    Button {
                        if let clip = UIPasteboard.general.string { input = clip }
                    } label: {
                        Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .tint(Color.stashAmber)
                }

                Spacer()

                Button(action: save) {
                    HStack {
                        if saving { ProgressView().tint(.stashNavy) }
                        Text(saving ? "Saving…" : "Save to VaultyPro")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color.stashNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.stashAmber.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(AppMetrics.hPadding)
            .background(Color.stashBackground.ignoresSafeArea())
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.stashAmber)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func save() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !pro.isPro && items.count >= AppConfig.Free.maxItems {
            showPaywall = true
            return
        }

        saving = true
        let item = ItemSaver.insertDraft(from: isURL ? .url(trimmed) : .text(trimmed), into: context)
        Task {
            await ItemSaver.enrich(item, in: context)
            saving = false
            dismiss()
        }
    }
}
