import Foundation
import Observation

/// Runs a three-phase sweep against Cloudflare's public speed-test endpoints:
/// latency probes, then a timed download, then a timed upload. Live throughput
/// is sampled a few times a second so the gauge moves with the real transfer.
@MainActor
@Observable
final class SpeedTestEngine {
    enum Phase: Equatable {
        case idle, latency, download, upload, done
        case failed(String)
    }

    var phase: Phase = .idle
    var liveMbps: Double = 0
    var downloadMbps: Double?
    var uploadMbps: Double?
    var latencyMs: Double?
    var jitterMs: Double?

    var isRunning: Bool {
        switch phase {
        case .latency, .download, .upload: return true
        default: return false
        }
    }

    var hasResult: Bool { downloadMbps != nil }

    /// Gauge position on a log scale where 1000 Mbps fills the arc.
    var gaugeFraction: Double {
        let value = isRunning ? liveMbps : (downloadMbps ?? 0)
        guard value > 0 else { return 0 }
        return min(1, log10(1 + value) / 3)
    }

    var statusText: String {
        switch phase {
        case .idle: return "Ready"
        case .latency: return "Measuring latency"
        case .download: return "Testing download"
        case .upload: return "Testing upload"
        case .done: return "Complete"
        case .failed(let message): return message
        }
    }

    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        downloadMbps = nil
        uploadMbps = nil
        latencyMs = nil
        jitterMs = nil
        liveMbps = 0
        task = Task { await run() }
    }

    func stop() {
        task?.cancel()
        task = nil
        liveMbps = 0
        phase = .idle
    }

    private func run() async {
        do {
            phase = .latency
            (latencyMs, jitterMs) = try await measureLatency()
            phase = .download
            downloadMbps = try await measureThroughput(.download)
            phase = .upload
            uploadMbps = try await measureThroughput(.upload)
            liveMbps = 0
            phase = .done
        } catch is CancellationError {
            // User pressed stop; state already reset.
        } catch {
            liveMbps = 0
            phase = .failed("Couldn't reach the test server")
        }
    }

    // MARK: - Latency

    private func measureLatency() async throws -> (Double, Double) {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
        let clock = ContinuousClock()
        var samples: [Double] = []
        for _ in 0..<6 {
            try Task.checkCancellation()
            let startedAt = clock.now
            _ = try await session.data(from: url)
            samples.append(seconds(clock.now - startedAt) * 1000)
        }
        // The first request pays for connection setup; measure the rest.
        let usable = Array(samples.dropFirst())
        let median = usable.sorted()[usable.count / 2]
        var diffs: [Double] = []
        for i in 1..<usable.count {
            diffs.append(abs(usable[i] - usable[i - 1]))
        }
        let jitter = diffs.reduce(0, +) / Double(diffs.count)
        return (median, jitter)
    }

    // MARK: - Throughput

    private enum Direction { case download, upload }

    private static let uploadPayload = Data(count: 32 * 1024 * 1024)

    private func measureThroughput(_ direction: Direction) async throws -> Double {
        let meter = ByteMeter()
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.timeoutIntervalForRequest = 12
        let session = URLSession(configuration: config, delegate: meter, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let window: Double = direction == .download ? 8 : 6
        startTransfer(direction, session: session, meter: meter)

        let clock = ContinuousClock()
        let startedAt = clock.now
        var firstByteAt: ContinuousClock.Instant?
        var lastBytes = 0
        var lastTime = startedAt
        var smoothed: Double = 0

        while true {
            try await Task.sleep(for: .milliseconds(180))
            try Task.checkCancellation()
            if let error = meter.error { throw error }

            let now = clock.now
            let bytes = meter.totalBytes
            if bytes > 0 && firstByteAt == nil { firstByteAt = now }
            let instant = Double(bytes - lastBytes) * 8 / seconds(now - lastTime) / 1_000_000
            lastBytes = bytes
            lastTime = now
            smoothed = smoothed == 0 ? instant : smoothed * 0.65 + instant * 0.35
            liveMbps = max(0, smoothed)

            if seconds(now - startedAt) >= window { break }

            // Keep the pipe saturated: chain another transfer when one completes.
            if meter.consumeFinished {
                startTransfer(direction, session: session, meter: meter)
            }
        }

        // Overall rate from the first byte, the way curl reports it —
        // instantaneous medians collapse to zero on slow, bursty links.
        let measuredFrom = firstByteAt ?? startedAt
        let elapsed = max(seconds(clock.now - measuredFrom), 0.3)
        return Double(meter.totalBytes) * 8 / elapsed / 1_000_000
    }

    private func startTransfer(_ direction: Direction, session: URLSession, meter: ByteMeter) {
        switch direction {
        case .download:
            // Cloudflare rejects requests above ~90 MB with a 403.
            let url = URL(string: "https://speed.cloudflare.com/__down?bytes=90000000")!
            session.dataTask(with: url).resume()
        case .upload:
            var request = URLRequest(url: URL(string: "https://speed.cloudflare.com/__up")!)
            request.httpMethod = "POST"
            meter.beginUploadSegment()
            session.uploadTask(with: request, from: Self.uploadPayload).resume()
        }
    }

    private nonisolated func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

/// Thread-safe byte counter fed by URLSession delegate callbacks.
private final class ByteMeter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var received = 0
    private var uploadedBase = 0
    private var uploadedCurrent = 0
    private var finished = false
    private var failure: Error?

    var totalBytes: Int {
        lock.withLock { received + uploadedBase + uploadedCurrent }
    }

    var error: Error? {
        lock.withLock { failure }
    }

    /// Reads and clears the finished flag so each completed transfer is handled once.
    var consumeFinished: Bool {
        lock.withLock {
            let value = finished
            finished = false
            return value
        }
    }

    func beginUploadSegment() {
        lock.withLock {
            uploadedBase += uploadedCurrent
            uploadedCurrent = 0
        }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            lock.withLock { failure = URLError(.badServerResponse) }
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock { received += data.count }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64
    ) {
        lock.withLock { uploadedCurrent = Int(totalBytesSent) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.withLock {
            if let error, (error as NSError).code != NSURLErrorCancelled {
                failure = error
            } else {
                finished = true
            }
        }
    }
}
