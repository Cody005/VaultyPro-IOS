import SwiftUI

/// A colored pill badge identifying a content type.
struct TypeBadgeView: View {
    let type: ContentType
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.systemImage)
                .font(.system(size: 9, weight: .bold))
            if !compact {
                Text(type.title.uppercased())
                    .font(AppFont.badge())
                    .tracking(0.5)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 5 : 4)
        .background(type.tint.gradient, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}

#Preview {
    HStack {
        ForEach(ContentType.allCases) { TypeBadgeView(type: $0) }
    }
    .padding()
    .background(Color.stashNavy)
}
