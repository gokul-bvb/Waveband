import SwiftUI

struct ContentView: View {
    @Environment(SignalMonitor.self) private var signal
    @Environment(SpeedTestEngine.self) private var engine

    var body: some View {
        ZStack {
            Backdrop()
            #if os(macOS)
            wideLayout
            #else
            ScrollView {
                compactLayout
            }
            .scrollIndicators(.hidden)
            #endif
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Layouts

    #if os(macOS)
    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            HStack(alignment: .center, spacing: 30) {
                gaugeCluster
                    .frame(width: 370)
                VStack(spacing: 14) {
                    metricRow
                    signalCard
                    TestButton()
                }
                .frame(maxWidth: .infinity)
            }
            SignalStrip()
        }
        .padding(28)
    }
    #endif

    private var compactLayout: some View {
        VStack(spacing: 26) {
            header
            gaugeCluster
                .padding(.vertical, -6)
            metricRow
            signalCard
            TestButton()
        }
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private var gaugeCluster: some View {
        ZStack {
            Wavefield(energy: fieldEnergy)
                .frame(width: 340, height: 340)
            SpeedGauge()
        }
    }

    /// The wavefield only runs during a sweep; it ramps in and out smoothly.
    private var fieldEnergy: Double {
        engine.isRunning ? 1 : 0
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WAVEBAND")
                .font(.system(size: 12, weight: .bold))
                .tracking(6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Palette.violet, Palette.cyan],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 11) {
                    StatusDot(connected: signal.isConnected)
                    Text(signal.networkName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Palette.bright)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(signal.statusLine)
                    .font(.system(size: 13, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Palette.fog)
                    .padding(.leading, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricRow: some View {
        HStack(spacing: 12) {
            MetricTile(
                label: "DOWN",
                value: speedString(engine.isRunning && engine.phase == .download
                    ? engine.liveMbps : engine.downloadMbps),
                unit: "Mbps",
                color: Palette.cyan
            )
            MetricTile(
                label: "UP",
                value: speedString(engine.isRunning && engine.phase == .upload
                    ? engine.liveMbps : engine.uploadMbps),
                unit: "Mbps",
                color: Palette.violet
            )
            MetricTile(
                label: "PING",
                value: msString(engine.latencyMs),
                unit: "ms",
                color: Palette.magenta
            )
        }
    }

    @ViewBuilder private var signalCard: some View {
        #if os(macOS)
        GlassCard {
            Eyebrow(text: "RADIO", color: Palette.fog.opacity(0.8))
            DetailRow(
                label: "SIGNAL",
                value: signal.isConnected ? "\(signal.rssi) dBm" : "—",
                barFraction: signal.quality,
                barColor: qualityColor(signal.quality)
            )
            DetailRow(
                label: "NOISE FLOOR",
                value: signal.isConnected ? "\(signal.noise) dBm" : "—"
            )
            DetailRow(
                label: "SIGNAL / NOISE",
                value: signal.isConnected ? "\(signal.snr) dB" : "—",
                barFraction: signal.isConnected
                    ? min(1, max(0, Double(signal.snr) / 50)) : nil,
                barColor: qualityColor(min(1, max(0, Double(signal.snr) / 50)))
            )
            DetailRow(
                label: "CHANNEL",
                value: signal.isConnected && signal.channel > 0
                    ? "\(signal.channel) · \(signal.band)" : "—"
            )
            DetailRow(
                label: "PHY RATE",
                value: signal.isConnected && signal.phyRateMbps > 0
                    ? "\(Int(signal.phyRateMbps)) Mbps" : "—"
            )
            DetailRow(
                label: "JITTER",
                value: engine.jitterMs.map { msString($0) + " ms" } ?? "—"
            )
        }
        #else
        GlassCard {
            Eyebrow(text: "LINK", color: Palette.fog.opacity(0.8))
            DetailRow(label: "INTERFACE", value: signal.networkName)
            DetailRow(
                label: "PATH",
                value: signal.isConnected
                    ? (signal.isExpensive ? "Metered" : "Unmetered") : "—"
            )
            DetailRow(
                label: "JITTER",
                value: engine.jitterMs.map { msString($0) + " ms" } ?? "—"
            )
            Text("iOS keeps radio strength private to apps, so quality here is measured from live throughput and latency.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.fog.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        #endif
    }
}
