import SwiftUI

/// The app's signature: radio wavefronts propagating out from the gauge.
/// Still while idle — the field wakes with an eased ramp when a sweep starts,
/// runs at 30 fps during the test, ramps back down, then stops rendering
/// entirely so an idle window costs no CPU.
struct Wavefield: View {
    /// Target energy: 1 while a test is running, 0 otherwise.
    var energy: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var rampFrom: Double = 0
    @State private var rampTarget: Double = 0
    @State private var rampStartedAt: Date = .distantPast
    @State private var idlePaused = true

    private let rampDuration: Double = 1.4

    private var paused: Bool {
        reduceMotion || scenePhase != .active || idlePaused
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            Canvas { graphics, size in
                let now = context.date
                let level = easedEnergy(at: now)
                let time = now.timeIntervalSinceReferenceDate
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

                // Propagating wavefronts, visible only while energized.
                // Ring speed must stay constant: phase is absolute-time × speed,
                // so a speed that changes while time is ~10^8 s teleports every
                // ring each frame. The ramp drives brightness only.
                guard level > 0.005 else { return }
                let ringCount = 7
                let speed = 0.22
                for index in 0..<ringCount {
                    let phase = (time * speed + Double(index) / Double(ringCount))
                        .truncatingRemainder(dividingBy: 1)
                    let radius = maxRadius * (0.30 + 0.70 * phase)
                    let alpha = (1 - phase) * 0.36 * level
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
        .onAppear {
            rampFrom = energy
            rampTarget = energy
            idlePaused = energy <= 0.005
        }
        .onChange(of: energy) { _, newTarget in
            rampFrom = easedEnergy(at: Date())
            rampTarget = newTarget
            rampStartedAt = Date()
            idlePaused = false
            if newTarget <= 0.005 {
                // Let the ramp-out finish, then stop the timeline for good.
                Task {
                    try? await Task.sleep(for: .seconds(rampDuration + 0.2))
                    if rampTarget <= 0.005 { idlePaused = true }
                }
            }
        }
    }

    /// Current energy along a smoothstep ramp between the last two targets.
    private func easedEnergy(at date: Date) -> Double {
        let progress = min(1, max(0, date.timeIntervalSince(rampStartedAt) / rampDuration))
        let eased = progress * progress * (3 - 2 * progress)
        return rampFrom + (rampTarget - rampFrom) * eased
    }
}
