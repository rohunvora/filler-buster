import SwiftUI

/// Design tokens - warm minimal with subtle depth
enum Theme {
    // Colors
    static let background = Color(hex: "#f7f5f2")
    static let text = Color(hex: "#2d2a26")
    static let textMuted = Color(hex: "#7a756e")
    static let accent = Color(hex: "#e8a87c")
    static let filler = Color(hex: "#e8a87c").opacity(0.3)
    static let recording = Color(hex: "#e85d5d")
    static let card = Color.white

    // Depth tokens (subtle skeuomorphism)
    static let cardShadow = Color.black.opacity(0.06)
    static let pressedBackground = Color(hex: "#f0ede9")
    static let buttonHighlight = Color.white.opacity(0.25)
    static let pinstripeOpacity: Double = 0.018
}

/// Subtle vertical pinstripes for retro texture
struct PinstripeBackground: View {
    var opacity: Double = Theme.pinstripeOpacity

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 4
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: 1)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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
