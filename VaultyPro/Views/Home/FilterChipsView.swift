import SwiftUI

/// Horizontal scrolling filter chips for the Home inbox.
struct FilterChipsView: View {
    @Binding var selection: HomeFilter
    var counts: [HomeFilter: Int] = [:]
    @Namespace private var ns

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(HomeFilter.allCases) { filter in
                    chip(filter)
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.vertical, 2)
        }
    }

    private func chip(_ filter: HomeFilter) -> some View {
        let selected = selection == filter
        let tint = filter.tint
        return Button {
            withAnimation(.snappy(duration: 0.28)) { selection = filter }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Color.stashNavy : tint)
                Text(filter.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(selected ? Color.stashNavy : .primary)
                if let count = counts[filter], count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected ? Color.stashNavy.opacity(0.75) : .secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(selected ? Color.stashNavy.opacity(0.16) : tint.opacity(0.18),
                                    in: Capsule())
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 40)
            .background {
                if selected {
                    Capsule()
                        .fill(tint.gradient)
                        .matchedGeometryEffect(id: "chip", in: ns)
                } else {
                    Capsule().fill(Color.stashCardSurface)
                        .overlay(Capsule().strokeBorder(Color.stashMuted.opacity(0.22)))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
