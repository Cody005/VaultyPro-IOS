import SwiftUI

/// A large, left-aligned page title with optional trailing actions on the same line.
/// Replaces the system large-title bar so the title and action buttons share one baseline.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

/// A glass capsule grouping one or more header icon buttons, matching the action bar style.
struct HeaderActionGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 18) {
            content()
        }
        .font(.system(size: 20, weight: .semibold))
        .tint(Color.stashAmber)
        .foregroundStyle(Color.stashAmber)
        .padding(.horizontal, 17)
        .frame(height: 42)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}
