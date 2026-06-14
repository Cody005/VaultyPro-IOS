import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch cleaned.count {
        case 8: // RRGGBBAA
            r = Double((rgb & 0xFF000000) >> 24) / 255
            g = Double((rgb & 0x00FF0000) >> 16) / 255
            b = Double((rgb & 0x0000FF00) >> 8) / 255
            a = Double(rgb & 0x000000FF) / 255
        case 6: // RRGGBB
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
            a = 1
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - VaultyPro palette

    // Primaries
    static let stashNavy    = Color(hex: "#0D1B2A")   // deep navy — primary BG in dark
    static let stashAmber   = Color(hex: "#F4A261")   // warm amber — accent / CTAs
    static let stashCream   = Color(hex: "#F8F4EE")   // warm cream — primary BG in light

    // Semantic
    static let stashSurface = Color(hex: "#1A2A3A")   // card surface dark
    static let stashMuted   = Color(hex: "#6B7C93")   // secondary text
    static let stashGreen   = Color(hex: "#52B788")   // success / read indicator
    static let stashRed     = Color(hex: "#E76F51")   // delete / destructive

    // Type badges
    static let typeArticle  = Color(hex: "#4ECDC4")
    static let typeVideo    = Color(hex: "#FF6B6B")
    static let typeAudio    = Color(hex: "#A8DADC")
    static let typeImage    = Color(hex: "#C77DFF")
    static let typeLink     = Color(hex: "#F4A261")
    static let typeNote     = Color(hex: "#95D5B2")
}

extension Color {
    /// Adaptive primary background (cream in light, navy in dark).
    static var stashBackground: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color.stashNavy)
                : UIColor(Color.stashCream)
        })
    }

    /// Adaptive card surface.
    static var stashCardSurface: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color.stashSurface)
                : UIColor.white
        })
    }
}
