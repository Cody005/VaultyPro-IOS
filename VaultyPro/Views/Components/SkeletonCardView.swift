import SwiftUI

/// Shimmering placeholder shown while content loads.
struct SkeletonCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.stashMuted.opacity(0.25))
                .aspectRatio(16/9, contentMode: .fit)

            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Color.stashMuted.opacity(0.25)).frame(width: 90, height: 10)
                Capsule().fill(Color.stashMuted.opacity(0.25)).frame(height: 12)
                Capsule().fill(Color.stashMuted.opacity(0.25)).frame(width: 140, height: 12)
            }
            .padding(14)
        }
        .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
        .shimmering()
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
            ForEach(0..<6, id: \.self) { _ in SkeletonCardView() }
        }
        .padding()
    }
    .background(Color.stashBackground)
}
