import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Palette {
    /// Deep violet ink — the night sky the spectrum lives against.
    static let ink = Color(hex: 0x0D0A1E)
    static let raised = Color.white.opacity(0.045)
    static let hairline = Color.white.opacity(0.09)
    static let fog = Color.white.opacity(0.55)
    static let bright = Color(hex: 0xF2EFFF)

    static let cyan = Color(hex: 0x53E8FF)
    static let violet = Color(hex: 0x9B6BFF)
    static let magenta = Color(hex: 0xFF5CA8)
    static let solar = Color(hex: 0xFFC85C)

    /// Energy rising: violet → magenta → solar → cyan.
    static let spectrum: [Color] = [violet, magenta, solar, cyan]
}

/// Poor → strong link quality mapped onto the palette.
func qualityColor(_ quality: Double) -> Color {
    if quality < 0.35 { return Palette.magenta }
    if quality < 0.65 { return Palette.solar }
    return Palette.cyan
}

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.fog

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(2.6)
            .foregroundStyle(color)
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Palette.ink
            RadialGradient(
                colors: [Palette.violet.opacity(0.17), .clear],
                center: UnitPoint(x: 0.12, y: -0.08),
                startRadius: 0, endRadius: 480
            )
            RadialGradient(
                colors: [Palette.cyan.opacity(0.10), .clear],
                center: UnitPoint(x: 0.95, y: 0.22),
                startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [Palette.magenta.opacity(0.09), .clear],
                center: UnitPoint(x: 0.5, y: 1.1),
                startRadius: 0, endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

func speedString(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    if value >= 100 { return String(format: "%.0f", value) }
    if value >= 10 { return String(format: "%.1f", value) }
    return String(format: "%.2f", value)
}

func msString(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    return value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
}
