import SwiftUI

// Design tokens matching the web app (globals.css)
extension Color {
    static let appBackground = Color(hex: "#f7f5f2")    // Warm beige
    static let textPrimary = Color(hex: "#2d2a26")
    static let textMuted = Color(hex: "#7a756e")
    static let accent = Color(hex: "#e8a87c")           // Tan/orange
    static let accentDark = Color(hex: "#c98860")
    static let recording = Color(hex: "#e85d5d")        // Red
    static let cardBackground = Color.white
    static let cardBorder = Color(hex: "#f0ece8")
    static let errorBackground = Color(hex: "#fff5f5")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
