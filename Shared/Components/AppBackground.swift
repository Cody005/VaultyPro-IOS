import SwiftUI

/// App-wide backdrop: a soft vertical wash, two faint brand-colored ambient glows for
/// depth, and a fine film grain for a premium, non-flat finish. Adapts to light/dark and
/// stays deliberately subtle so content remains the focus.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            // Base vertical wash — a touch lighter at the top.
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(hex: "#13243A"), Color(hex: "#0B1622"), Color(hex: "#091320")]
                    : [Color(hex: "#FCF8F2"), Color(hex: "#F3ECE1"), Color(hex: "#EEE6D9")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Single cohesive cool glow in the upper-right, tinted to match the navy
            // theme (no warm/amber clash). Kept soft so it reads as ambient depth.
            RadialGradient(
                colors: [Color(hex: "#3A7CA5").opacity(scheme == .dark ? 0.14 : 0.06), .clear],
                center: .init(x: 0.92, y: 0.02),
                startRadius: 0,
                endRadius: 400
            )

            // Hand-rendered film grain: adds tactile texture and hides gradient banding.
            GrainOverlay()
                .opacity(scheme == .dark ? 0.05 : 0.035)
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}

/// A tiled, procedurally generated grain texture (rendered once and cached).
private struct GrainOverlay: View {
    var body: some View {
        Image(uiImage: Self.texture)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    /// 140×140 monochrome noise tile, generated a single time at launch.
    static let texture: UIImage = {
        let side = 140
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(white: 0.5, alpha: 0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<(side * side / 2) {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                UIColor(white: .random(in: 0...1), alpha: 1).setFill()
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }()
}
