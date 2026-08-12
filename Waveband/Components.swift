import SwiftUI

struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.fog)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
        )
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var barFraction: Double?
    var barColor: Color = Palette.cyan

    var body: some View {
        HStack(alignment: .center) {
            Eyebrow(text: label)
            Spacer(minLength: 12)
            if let barFraction {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(barColor)
                            .frame(width: max(6, 72 * barFraction), height: 4)
                            .animation(.easeOut(duration: 0.6), value: barFraction)
                    }
                    .padding(.trailing, 10)
            }
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.bright)
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
        )
    }
}

/// Standby light for the connection. Static by design — continuous ambient
/// animation costs a Core Animation commit per frame even when tiny.
struct StatusDot: View {
    let connected: Bool

    private var color: Color { connected ? Palette.cyan : Palette.magenta }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(0.7), radius: 5)
            .accessibilityLabel(connected ? "Connected" : "Offline")
    }
}

struct TestButton: View {
    var compact = false

    @Environment(SpeedTestEngine.self) private var engine
    @Environment(SignalMonitor.self) private var signal

    private var title: String {
        if engine.isRunning { return "Stop test" }
        return engine.hasResult ? "Test again" : "Run speed test"
    }

    var body: some View {
        Button {
            engine.isRunning ? engine.stop() : engine.start()
        } label: {
            Text(title)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(engine.isRunning ? Palette.magenta : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 38 : 54)
                .background(buttonBackground)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!signal.isConnected && !engine.isRunning)
        .opacity(signal.isConnected || engine.isRunning ? 1 : 0.4)
    }

    @ViewBuilder private var buttonBackground: some View {
        if engine.isRunning {
            Capsule()
                .fill(Palette.raised)
                .overlay(Capsule().strokeBorder(Palette.magenta.opacity(0.6), lineWidth: 1.5))
        } else {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Palette.violet, Palette.cyan],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Palette.cyan.opacity(compact ? 0.25 : 0.35), radius: compact ? 8 : 16, y: compact ? 2 : 4)
        }
    }
}
