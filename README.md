# Waveband

A lightweight Wi-Fi signal and speed instrument for macOS and iOS, built with
SwiftUI in a single multiplatform target.

## What it shows

- **Speed test** (both platforms): latency + jitter probes, then timed download
  and upload sweeps against Cloudflare's public speed-test endpoints
  (`speed.cloudflare.com`). The gauge is a 270° dial on a log scale
  (1 → 1000 Mbps) that moves live with the transfer.
- **Radio details** (macOS): RSSI, noise floor, SNR, channel + band, and PHY
  rate via CoreWLAN, refreshed every 2 seconds. macOS asks for location
  permission once — that's only so the OS will reveal the network name; nothing
  leaves the machine.
- **Link details** (iOS): active interface and path flags via NWPathMonitor.
  iOS doesn't expose radio strength to third-party apps, and the app says so
  rather than faking it.

## Running it

Open `Waveband.xcodeproj` in Xcode and run the single `Waveband` scheme —
pick a Mac or iPhone destination. No dependencies, no packages.

To run on a physical iPhone, set your development team under
Signing & Capabilities first.

## Layout

- `WavebandApp.swift` — app entry, window sizing
- `ContentView.swift` — screen layout
- `SpeedGauge.swift`, `Wavefield.swift`, `Components.swift` — the instrument UI
- `SpeedTestEngine.swift` — latency/download/upload measurement
- `SignalMonitor.swift` — CoreWLAN (macOS) / NWPathMonitor (iOS)
- `Theme.swift` — palette and shared styles
