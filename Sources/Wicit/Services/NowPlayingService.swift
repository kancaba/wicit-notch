import AppKit
import Combine

struct NowPlayingTrack {
    var title: String
    var artist: String
    var appName: String
    var appIcon: NSImage?
    var isPlaying: Bool
    var artwork: NSImage?

    /// Playback position in seconds at `fetchedAt`, and total duration.
    var position: Double
    var duration: Double
    var fetchedAt: Date

    /// Interpolated position for smooth progress between updates.
    func position(at date: Date) -> Double {
        guard isPlaying else { return position }
        let value = position + date.timeIntervalSince(fetchedAt)
        return duration > 0 ? min(duration, value) : value
    }
}

/// Universal now-playing via the bundled mediaremote-adapter
/// (github.com/ungive/mediaremote-adapter, BSD-3): a helper framework loaded
/// through Apple-signed /usr/bin/perl streams the system's MediaRemote state as
/// JSON lines. Covers every media source (Music, Spotify, Chrome, Safari, …)
/// just like the native menu-bar player, with no TCC permission required.
final class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()

    @Published private(set) var track: NowPlayingTrack?

    private var process: Process?
    private var stdoutBuffer = Data()
    /// Accumulated now-playing state (stream sends diffs).
    private var state: [String: Any] = [:]
    private var artworkCache: (base64: String, image: NSImage)?
    private var appInfoCache: [String: (name: String, icon: NSImage)] = [:]
    private var isStopped = false

    private init() {
        start()
    }

    // MARK: - Adapter process

    private var adapterDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("MediaRemoteAdapter", isDirectory: true)
    }

    private func start() {
        guard let dir = adapterDirectory else { return }
        let script = dir.appendingPathComponent("mediaremote-adapter.pl")
        let framework = dir.appendingPathComponent("MediaRemoteAdapter.framework")
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: framework.path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, framework.path, "stream", "--micros", "--debounce=100"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { self?.consume(data) }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, !self.isStopped else { return }
                self.track = nil
                self.state = [:]
                // The adapter died (e.g. after sleep) — relaunch shortly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.start() }
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            self.process = nil
        }
    }

    /// Terminate the helper; called on app quit.
    func stop() {
        isStopped = true
        process?.terminate()
        process = nil
    }

    // MARK: - Stream parsing

    private func consume(_ data: Data) {
        stdoutBuffer.append(data)
        while let newline = stdoutBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newline)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newline)
            handle(line: line)
        }
    }

    private func handle(line: Data) {
        guard !line.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: line),
              let dict = object as? [String: Any],
              dict["type"] as? String == "data" else { return }

        let payload = dict["payload"] as? [String: Any] ?? [:]
        let isDiff = dict["diff"] as? Bool ?? false

        if isDiff {
            for (key, value) in payload {
                if value is NSNull {
                    state.removeValue(forKey: key)
                } else {
                    state[key] = value
                }
            }
        } else {
            state = payload.filter { !($0.value is NSNull) }
        }
        rebuildTrack()
    }

    private func rebuildTrack() {
        guard let title = state["title"] as? String,
              let bundleID = state["bundleIdentifier"] as? String,
              let playing = state["playing"] as? Bool else {
            track = nil
            return
        }

        let duration = micros("durationMicros")
        let position = micros("elapsedTimeMicros")
        let timestampMicros = (state["timestampEpochMicros"] as? NSNumber)?.doubleValue
        let fetchedAt = timestampMicros.map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? Date()

        let ownerID = (state["parentApplicationBundleIdentifier"] as? String) ?? bundleID
        let app = appInfo(for: ownerID)

        track = NowPlayingTrack(
            title: title,
            artist: state["artist"] as? String ?? "",
            appName: app?.name ?? "",
            appIcon: app?.icon,
            isPlaying: playing,
            artwork: artwork(),
            position: position,
            duration: duration,
            fetchedAt: fetchedAt
        )
    }

    private func micros(_ key: String) -> Double {
        ((state[key] as? NSNumber)?.doubleValue ?? 0) / 1_000_000
    }

    private func artwork() -> NSImage? {
        guard let base64 = state["artworkData"] as? String else { return nil }
        if let cached = artworkCache, cached.base64 == base64 { return cached.image }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let image = NSImage(data: data) else { return nil }
        artworkCache = (base64, image)
        return image
    }

    private func appInfo(for bundleID: String) -> (name: String, icon: NSImage)? {
        if let cached = appInfoCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 28, height: 28)
        let info = (FileManager.default.displayName(atPath: url.path), icon)
        appInfoCache[bundleID] = info
        return info
    }

    // MARK: - Controls (MediaRemote send)

    func playPause() {
        send(2)
        // Optimistic flip for a snappy UI; the stream confirms shortly after.
        if var current = track {
            current.position = current.position(at: Date())
            current.fetchedAt = Date()
            current.isPlaying.toggle()
            track = current
        }
    }

    func next() { send(4) }
    func previous() { send(5) }

    private func send(_ command: Int) {
        guard let dir = adapterDirectory else { return }
        let script = dir.appendingPathComponent("mediaremote-adapter.pl")
        let framework = dir.appendingPathComponent("MediaRemoteAdapter.framework")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, framework.path, "send", String(command)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
