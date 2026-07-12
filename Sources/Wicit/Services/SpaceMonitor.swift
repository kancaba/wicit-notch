import AppKit
import Combine

/// Tracks which macOS Space (virtual desktop) is active. Apple exposes no
/// public API for Space identity — only "it changed" — so we resolve the id
/// through the private SkyLight/CoreGraphics `*GetActiveSpace` call, loaded
/// dynamically. If the symbol ever disappears in a macOS update the app
/// degrades gracefully to a single-space experience (index 0).
final class SpaceMonitor: ObservableObject {
    static let shared = SpaceMonitor()

    /// Stable, 0-based index of the active Space, ordered by first appearance.
    @Published private(set) var spaceIndex: Int = 0

    /// Whether Space identity resolution is actually available.
    let isAvailable: Bool

    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias ActiveSpaceFn = @convention(c) (Int32) -> UInt64

    private let connection: Int32
    private let activeSpace: ActiveSpaceFn?
    private var knownSpaces: [UInt64] {
        didSet {
            UserDefaults.standard.set(knownSpaces.map(String.init), forKey: Self.defaultsKey)
        }
    }

    private static let defaultsKey = "wicit.knownSpaces"

    private init() {
        // Try SkyLight (SLS*) first, then CoreGraphics (CGS*).
        let candidates: [(path: String, conn: String, space: String)] = [
            ("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
             "SLSMainConnectionID", "SLSGetActiveSpace"),
            ("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
             "CGSMainConnectionID", "CGSGetActiveSpace")
        ]

        var conn: Int32 = 0
        var spaceFn: ActiveSpaceFn?
        for candidate in candidates {
            guard let handle = dlopen(candidate.path, RTLD_LAZY),
                  let connSym = dlsym(handle, candidate.conn),
                  let spaceSym = dlsym(handle, candidate.space) else { continue }
            conn = unsafeBitCast(connSym, to: ConnectionFn.self)()
            spaceFn = unsafeBitCast(spaceSym, to: ActiveSpaceFn.self)
            break
        }
        connection = conn
        activeSpace = spaceFn
        isAvailable = spaceFn != nil

        let stored = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        knownSpaces = stored.compactMap(UInt64.init)

        update()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() {
        update()
    }

    private func update() {
        guard let activeSpace else { return }
        let id = activeSpace(connection)
        guard id != 0 else { return }
        if let index = knownSpaces.firstIndex(of: id) {
            if spaceIndex != index { spaceIndex = index }
        } else {
            knownSpaces.append(id)
            spaceIndex = knownSpaces.count - 1
        }
    }
}
