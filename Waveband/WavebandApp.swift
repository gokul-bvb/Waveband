import SwiftUI

@main
struct WavebandApp: App {
    @State private var signal = SignalMonitor()
    @State private var engine = SpeedTestEngine()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(signal)
                .environment(engine)
                #if os(macOS)
                .frame(width: 880)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        MenuBarExtra("Waveband", systemImage: "dot.radiowaves.left.and.right") {
            MenuBarPanel()
                .environment(signal)
                .environment(engine)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
