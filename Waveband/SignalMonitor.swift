import Foundation
import Observation

#if os(macOS)
import CoreWLAN
import CoreLocation

/// Reads live radio details from the Mac's Wi-Fi interface via CoreWLAN.
/// Location authorization is requested only so macOS will reveal the SSID.
@MainActor
@Observable
final class SignalMonitor {
    var isConnected = false
    var ssid: String?
    var rssi = 0
    var noise = 0
    var channel = 0
    var band = ""
    var phyRateMbps: Double = 0
    /// Recent RSSI samples, newest last — one per poll tick.
    var history: [Int] = []

    private let historyLimit = 120

    var snr: Int { rssi - noise }

    /// 0–1, mapped from RSSI −90…−40 dBm.
    var quality: Double {
        guard isConnected else { return 0 }
        return min(1, max(0, (Double(rssi) + 90) / 50))
    }

    var networkName: String {
        guard isConnected else { return "Not connected" }
        return ssid ?? "Wi-Fi network"
    }

    var statusLine: String {
        guard isConnected else { return "Join a Wi-Fi network to begin" }
        var parts: [String] = []
        if !band.isEmpty { parts.append(band) }
        if channel > 0 { parts.append("Channel \(channel)") }
        if phyRateMbps > 0 { parts.append("\(Int(phyRateMbps)) Mbps link") }
        return parts.joined(separator: "  ·  ")
    }

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let location = CLLocationManager()

    init() {
        location.requestWhenInUseAuthorization()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func refresh() {
        guard let interface = CWWiFiClient.shared().interface(),
              let wlanChannel = interface.wlanChannel(),
              interface.rssiValue() != 0
        else {
            isConnected = false
            history.removeAll()
            return
        }
        isConnected = true
        ssid = interface.ssid()
        rssi = interface.rssiValue()
        history.append(rssi)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
        noise = interface.noiseMeasurement()
        phyRateMbps = interface.transmitRate()
        channel = wlanChannel.channelNumber
        switch wlanChannel.channelBand {
        case .band2GHz: band = "2.4 GHz"
        case .band5GHz: band = "5 GHz"
        case .band6GHz: band = "6 GHz"
        default: band = ""
        }
    }
}

#else
import Network

/// iOS keeps radio internals private, so the monitor reports what the system
/// does share: the active interface and its path characteristics.
@MainActor
@Observable
final class SignalMonitor {
    var isConnected = false
    var interfaceLabel = "—"
    var isExpensive = false
    var isConstrained = false

    var networkName: String {
        isConnected ? interfaceLabel : "Not connected"
    }

    var statusLine: String {
        guard isConnected else { return "Join a network to begin" }
        var parts = [isExpensive ? "Metered" : "Unmetered"]
        if isConstrained { parts.append("Low-data mode") }
        return parts.joined(separator: "  ·  ")
    }

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in self.apply(path) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    private func apply(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        if path.usesInterfaceType(.wifi) {
            interfaceLabel = "Wi-Fi"
        } else if path.usesInterfaceType(.cellular) {
            interfaceLabel = "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            interfaceLabel = "Ethernet"
        } else {
            interfaceLabel = "Network"
        }
    }
}
#endif
