import SwiftUI

/// A selectable / removable tag chip.
struct TagChipView: View {
    let text: String
    var isSelected: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 5) {
            Text("#\(text)")
                .font(.system(size: 13, weight: .medium))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(isSelected ? Color.stashNavy : Color.stashAmber)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(isSelected ? AnyShapeStyle(Color.stashAmber) : AnyShapeStyle(Color.stashAmber.opacity(0.14)))
        }
        .overlay(
            Capsule().strokeBorder(Color.stashAmber.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
        )
    }
}

#Preview {
    HStack {
        TagChipView(text: "design")
        TagChipView(text: "swift", isSelected: true)
        TagChipView(text: "video", onRemove: {})
    }
    .padding()
}
