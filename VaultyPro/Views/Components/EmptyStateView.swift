import SwiftUI

/// An illustrated empty state with icon, headline, subtext and optional CTA.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var ctaTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.stashMuted.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .strokeBorder(Color.stashMuted.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
            }

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let ctaTitle, let action {
                Button(action: action) {
                    Text(ctaTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.stashNavy)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.stashAmber, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "Nothing saved yet",
        message: "Tap Share → VaultyPro from any app to save something.",
        ctaTitle: "Add a link",
        action: {}
    )
}
