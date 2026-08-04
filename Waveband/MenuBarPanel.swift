#if os(macOS)
import SwiftUI

/// Compact control that lives in the menu bar: current network, last results,
/// and a button to run the sweep without opening the main window.
struct MenuBarPanel: View {
    @Environment(SignalMonitor.self) private var signal
    @Environment(SpeedTestEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(signal.isConnected ? Palette.cyan : Palette.magenta)
                    .frame(width: 7, height: 7)
                    .shadow(color: signal.isConnected ? Palette.cyan : Palette.magenta, radius: 3)
                Text(signal.networkName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.bright)
                    .lineLimit(1)
                Spacer(minLength: 12)
                statusBadge
            }

            HStack(spacing: 10) {
                miniMetric(
                    "DOWN",
                    speedString(engine.isRunning && engine.phase == .download
                        ? engine.liveMbps : engine.downloadMbps),
                    "Mbps", Palette.cyan
                )
                miniMetric(
                    "UP",
                    speedString(engine.isRunning && engine.phase == .upload
                        ? engine.liveMbps : engine.uploadMbps),
                    "Mbps", Palette.violet
                )
                miniMetric("PING", msString(engine.latencyMs), "ms", Palette.magenta)
            }

            TestButton(compact: true)

            Divider()
                .overlay(Palette.hairline)

            HStack {
                Button("Open Waveband") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Palette.fog)
        }
        .padding(16)
        .frame(width: 310)
        .background(Palette.ink)
    }

    /// Phase shown as a compact icon so long network names keep their room.
    @ViewBuilder private var statusBadge: some View {
        if let (symbol, color) = badge {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Palette.raised))
                .overlay(Circle().strokeBorder(color.opacity(0.4), lineWidth: 1))
                .symbolEffect(.pulse, isActive: engine.isRunning)
                .accessibilityLabel(engine.statusText)
                .help(engine.statusText)
        }
    }

    private var badge: (String, Color)? {
        switch engine.phase {
        case .idle: return nil
        case .latency: return ("waveform.path.ecg", Palette.magenta)
        case .download: return ("arrow.down", Palette.cyan)
        case .upload: return ("arrow.up", Palette.violet)
        case .done: return ("checkmark", Palette.cyan)
        case .failed: return ("exclamationmark.triangle", Palette.magenta)
        }
    }

    private func miniMetric(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.fog)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
        )
    }
}
#endif
