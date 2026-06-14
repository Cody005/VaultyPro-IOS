import SwiftUI

struct ReaderSettingsSheet: View {
    @Bindable var model: DetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                group("Text Size", value: "\(Int(model.fontSize)) pt") {
                    HStack {
                        Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                        Slider(value: $model.fontSize, in: 14...26, step: 1).tint(Color.stashAmber)
                        Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
                    }
                }

                group("Line Spacing", value: "\(Int(model.lineSpacing))") {
                    Slider(value: $model.lineSpacing, in: 2...14, step: 1).tint(Color.stashAmber)
                }

                group("Font") {
                    Picker("Font", selection: $model.font) {
                        ForEach(ReaderFont.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }

                group("Background") {
                    HStack(spacing: 12) {
                        ForEach(ReaderBackground.allCases) { bg in
                            Button { model.background = bg } label: {
                                Circle().fill(bg.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(Circle().strokeBorder(model.background == bg ? Color.stashAmber : Color.stashMuted.opacity(0.4), lineWidth: 2))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
            }
            .padding(AppMetrics.hPadding)
            .background(Color.stashBackground.ignoresSafeArea())
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.stashAmber).fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func group<Content: View>(_ title: String, value: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(AppFont.sectionHeader())
                if let value {
                    Spacer()
                    Text(value).font(AppFont.sectionHeader()).foregroundStyle(Color.stashAmber)
                }
            }
            content()
        }
    }
}
