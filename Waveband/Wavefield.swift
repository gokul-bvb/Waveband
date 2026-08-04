import SwiftUI

/// The app's signature: radio wavefronts propagating out from the gauge.
/// Ring speed and brightness follow real activity — calm when idle,
/// energized while a sweep is running.
struct Wavefield: View {
    var energy: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            Canvas { graphics, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2

                // Faint static graticule, like an instrument dial.
                for step in 1...3 {
                    let radius = maxRadius * Double(step) / 3.4
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    graphics.stroke(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.035)),
                        lineWidth: 1
                    )
                }

                // Propagating wavefronts.
                let ringCount = 7
                let speed = 0.10 + 0.18 * energy
                for index in 0..<ringCount {
                    let phase = (time * speed + Double(index) / Double(ringCount))
                        .truncatingRemainder(dividingBy: 1)
                    let radius = maxRadius * (0.30 + 0.70 * phase)
                    let alpha = (1 - phase) * (0.06 + 0.30 * energy)
                    let color = Palette.spectrum[index % Palette.spectrum.count]
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    graphics.stroke(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(alpha)),
                        lineWidth: 1.2
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
