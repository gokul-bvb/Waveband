import SwiftUI

/// 270° instrument dial on a log scale: 1, 10, 100, 1000 Mbps.
struct SpeedGauge: View {
    @Environment(SpeedTestEngine.self) private var engine

    private let sweep = 0.75
    private let startDegrees = 135.0
    private let arcRadius: CGFloat = 128

    private var fraction: Double { engine.gaugeFraction }

    private var tipColor: Color {
        switch engine.phase {
        case .upload: return Palette.violet
        case .latency: return Palette.magenta
        default: return Palette.cyan
        }
    }

    var body: some View {
        ZStack {
            ticks
            scaleLabels

            Circle()
                .trim(from: 0, to: sweep)
                .stroke(
                    Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(startDegrees))
                .frame(width: arcRadius * 2, height: arcRadius * 2)

            Circle()
                .trim(from: 0, to: sweep * fraction)
                .stroke(
                    // The whole circle is rotated by startDegrees below, so the
                    // gradient runs 0–270° in the view's own coordinate space.
                    AngularGradient(
                        colors: Palette.spectrum,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(startDegrees))
                .frame(width: arcRadius * 2, height: arcRadius * 2)
                .shadow(color: tipColor.opacity(0.35), radius: 12)
                .animation(.spring(duration: 0.5), value: fraction)

            if fraction > 0.001 {
                Circle()
                    .fill(Palette.bright)
                    .frame(width: 9, height: 9)
                    .offset(tipOffset)
                    .shadow(color: tipColor, radius: 7)
                    .animation(.spring(duration: 0.5), value: fraction)
            }

            centerReadout
        }
        .frame(width: 320, height: 320)
    }

    private var centerReadout: some View {
        VStack(spacing: 4) {
            Text(engine.hasResult || engine.isRunning ? speedString(displayValue) : "—")
                .font(.system(size: 62, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(Palette.bright)
                .contentTransition(.numericText(value: displayValue))
                .animation(.snappy(duration: 0.3), value: speedString(displayValue))

            Text("Mbps")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.fog)

            Eyebrow(text: engine.statusText.uppercased(), color: statusColor)
                .padding(.top, 10)
        }
    }

    private var displayValue: Double {
        engine.isRunning ? engine.liveMbps : (engine.downloadMbps ?? 0)
    }

    private var statusColor: Color {
        switch engine.phase {
        case .failed: return Palette.magenta
        case .done: return Palette.cyan
        case .idle: return Palette.fog
        default: return tipColor
        }
    }

    private var ticks: some View {
        ForEach(0..<31, id: \.self) { index in
            let f = Double(index) / 30
            let major = index % 10 == 0
            Rectangle()
                .fill(Color.white.opacity(major ? 0.35 : 0.14))
                .frame(width: major ? 2 : 1, height: major ? 11 : 5)
                .offset(y: -(arcRadius + 22))
                .rotationEffect(.degrees(225 + 270 * f))
        }
    }

    private var scaleLabels: some View {
        ForEach(Array(["1", "10", "100", "1000"].enumerated()), id: \.offset) { index, label in
            let f = Double(index) / 3
            let radians: Double = (startDegrees + 270 * f) * .pi / 180
            let radius = Double(arcRadius) + 42
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.fog.opacity(0.8))
                .offset(x: radius * cos(radians), y: radius * sin(radians))
        }
    }

    private var tipOffset: CGSize {
        let radians: Double = (startDegrees + 270 * fraction) * .pi / 180
        let radius = Double(arcRadius)
        return CGSize(width: radius * cos(radians), height: radius * sin(radians))
    }
}
