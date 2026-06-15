import SwiftUI

// MARK: - PIN dots indicator

struct PINDotsView: View {
    let length: Int
    let total: Int = 6

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < length ? Color.stashAmber : Color.primary.opacity(0.2))
                    .frame(width: 14, height: 14)
                    .scaleEffect(i < length ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: length)
            }
        }
    }
}

// MARK: - Custom numeric pad

struct VaultPINPadView: View {
    @Binding var pin: String
    let maxDigits: Int = 6
    /// Called once the PIN reaches `maxDigits`.
    var onComplete: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let rows: [[String] ] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(row, id: \.self) { key in
                        if key == "" {
                            Color.clear.frame(width: padSize, height: padSize)
                        } else if key == "⌫" {
                            padButton(key) { deleteDigit() }
                        } else {
                            padButton(key) { append(key) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Key button

    private let padSize: CGFloat = 72

    private func padButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.stashCardSurface)
                    .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                if label == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text(label)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: padSize, height: padSize)
        }
        .buttonStyle(PINKeyButtonStyle())
    }

    // MARK: - Input logic

    private func append(_ digit: String) {
        guard pin.count < maxDigits else { return }
        pin += digit
        if pin.count == maxDigits {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onComplete(pin)
            }
        }
    }

    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }
}

// MARK: - Button style

private struct PINKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
