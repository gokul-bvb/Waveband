#if os(macOS)
import SwiftUI

/// Continuously scrolling RSSI meter — one bar per second, newest at the
/// right, colored by link quality. Reads like the level meter on a receiver.
struct SignalStrip: View {
    @Environment(SignalMonitor.self) private var signal

    var body: some View {
        GlassCard {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: "LIVE SIGNAL", color: Palette.fog.opacity(0.8))
                Spacer()
                if signal.isConnected {
                    HStack(spacing: 10) {
                        Text(qualityWord)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(qualityColor(signal.quality))
                        Text("\(signal.rssi) dBm")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Palette.bright)
                            .contentTransition(.numericText())
                    }
                }
            }

            Canvas { graphics, size in
                let slot = 5.0, barWidth = 3.0
                let capacity = Int(size.width / slot)
                let shown = signal.history.suffix(capacity)
                guard !shown.isEmpty else { return }

                for (offset, sample) in shown.enumerated() {
                    let quality = min(1, max(0, (Double(sample) + 90) / 50))
                    let height = max(3, (size.height - 4) * quality)
                    let x = size.width - Double(shown.count - offset) * slot
                    // Older samples fade toward the left edge.
                    let age = Double(offset) / Double(max(1, shown.count - 1))
                    let rect = CGRect(
                        x: x, y: size.height - height,
                        width: barWidth, height: height
                    )
                    graphics.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color(qualityColor(quality).opacity(0.30 + 0.70 * age))
                    )
                }
            }
            .frame(height: 54)
            .overlay {
                if signal.history.isEmpty {
                    Text("Waiting for signal")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.fog)
                }
            }
        }
    }

    private var qualityWord: String {
        if signal.quality >= 0.65 { return "Strong" }
        if signal.quality >= 0.35 { return "Fair" }
        return "Weak"
    }
}
#endif
