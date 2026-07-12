import AppKit
import Combine

/// Watches the general pasteboard (macOS has no change notification, so we poll
/// `changeCount`) and keeps a classified history — text, links, colors, images
/// and files — tagged with the source app and capture time.
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let maxItems = 100
    /// True while we write to the pasteboard ourselves, so we skip re-capturing.
    private var isWritingBack = false

    private var persistCancellable: AnyCancellable?

    private init() {
        lastChangeCount = pasteboard.changeCount
        restore()
        start()

        // Persist (debounced) whenever history changes.
        persistCancellable = $items
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.persist() }
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Polling

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard !isWritingBack else { return }
        guard let item = capture() else { return }
        insert(item)
    }

    private func capture() -> ClipItem? {
        let source = NSWorkspace.shared.frontmostApplication
        let sourceName = source?.localizedName
        let sourceIcon = source?.icon
        let sourceBundleID = source?.bundleIdentifier

        // 1. Files (Finder-style copies carry file URLs).
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            var item = ClipItem(kind: .file, date: Date())
            item.fileURLs = urls
            item.text = urls.map(\.lastPathComponent).joined(separator: ", ")
            item.sourceName = sourceName
            item.sourceIcon = sourceIcon
            item.sourceBundleID = sourceBundleID
            return item
        }

        // 2. Images.
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            var item = ClipItem(kind: .image, date: Date())
            item.image = image
            item.sourceName = sourceName
            item.sourceIcon = sourceIcon
            item.sourceBundleID = sourceBundleID
            return item
        }

        // 3. Strings → color / link / text.
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            var item: ClipItem
            if let color = Self.parseHexColor(trimmed) {
                item = ClipItem(kind: .color, date: Date())
                item.color = color
                item.text = trimmed.uppercased()
            } else if Self.isLink(trimmed) {
                item = ClipItem(kind: .link, date: Date())
                item.text = trimmed
            } else {
                item = ClipItem(kind: .text, date: Date())
                item.text = string
            }
            item.sourceName = sourceName
            item.sourceIcon = sourceIcon
            item.sourceBundleID = sourceBundleID
            return item
        }

        return nil
    }

    private func insert(_ item: ClipItem) {
        // Collapse consecutive duplicates of the same text.
        if let text = item.text, let first = items.first, first.text == text, first.kind == item.kind {
            return
        }
        items.insert(item, at: 0)
        // Keep favorites; only trim non-favorites past the cap.
        if items.count > maxItems {
            if let idx = items.lastIndex(where: { !$0.isFavorite }) {
                items.remove(at: idx)
            }
        }
    }

    // MARK: - Actions

    func copyToPasteboard(_ item: ClipItem) {
        isWritingBack = true
        pasteboard.clearContents()
        switch item.kind {
        case .text, .link:
            if let text = item.text { pasteboard.setString(text, forType: .string) }
        case .color:
            if let text = item.text { pasteboard.setString(text, forType: .string) }
        case .image:
            if let image = item.image { pasteboard.writeObjects([image]) }
        case .file:
            pasteboard.writeObjects(item.fileURLs as [NSURL])
        }
        lastChangeCount = pasteboard.changeCount
        // Release the guard shortly after so real copies resume being captured.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isWritingBack = false
        }
    }

    func toggleFavorite(_ item: ClipItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].isFavorite.toggle()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        items.removeAll { !$0.isFavorite }
    }

    // MARK: - Persistence

    /// History survives restarts: metadata as JSON, images as PNG files under
    /// Application Support. All favorites plus the most recent 50 are kept.
    private struct StoredItem: Codable {
        var id: UUID
        var kind: String
        var date: Date
        var text: String?
        var isFavorite: Bool
        var sourceName: String?
        var sourceBundleID: String?
        var filePaths: [String]
        var hasImage: Bool
    }

    private var storeDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Wicit/Clipboard", isDirectory: true)
    }

    private func imageURL(for id: UUID) -> URL {
        storeDirectory.appendingPathComponent("\(id.uuidString).png")
    }

    private func persist() {
        let dir = storeDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let favorites = items.filter(\.isFavorite)
        let recents = items.filter { !$0.isFavorite }.prefix(50)
        let keep = (favorites + recents).sorted { $0.date > $1.date }

        let stored = keep.map { item in
            StoredItem(
                id: item.id,
                kind: item.kind.rawValue,
                date: item.date,
                text: item.text,
                isFavorite: item.isFavorite,
                sourceName: item.sourceName,
                sourceBundleID: item.sourceBundleID,
                filePaths: item.fileURLs.map(\.path),
                hasImage: item.image != nil
            )
        }

        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: dir.appendingPathComponent("index.json"), options: .atomic)
        }

        // Write images for kept items; drop orphaned image files.
        let keptIDs = Set(keep.map(\.id))
        for item in keep where item.kind == .image {
            let url = imageURL(for: item.id)
            guard !FileManager.default.fileExists(atPath: url.path),
                  let tiff = item.image?.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: url)
        }
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "png" {
                let name = file.deletingPathExtension().lastPathComponent
                if let id = UUID(uuidString: name), !keptIDs.contains(id) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    private func restore() {
        let indexURL = storeDirectory.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let stored = try? JSONDecoder().decode([StoredItem].self, from: data) else { return }

        items = stored.compactMap { entry in
            guard let kind = ClipItem.Kind(rawValue: entry.kind) else { return nil }
            var item = ClipItem(kind: kind, date: entry.date)
            item.id = entry.id
            item.text = entry.text
            item.isFavorite = entry.isFavorite
            item.sourceName = entry.sourceName
            item.sourceBundleID = entry.sourceBundleID
            item.fileURLs = entry.filePaths.map { URL(fileURLWithPath: $0) }

            if kind == .image {
                item.image = NSImage(contentsOf: imageURL(for: entry.id))
            }
            if kind == .color, let text = item.text {
                item.color = Self.parseHexColor(text)
            }
            // Re-derive the source app icon from its bundle id.
            if let bundleID = entry.sourceBundleID,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                icon.size = NSSize(width: 28, height: 28)
                item.sourceIcon = icon
            }
            return item
        }
    }

    // MARK: - Classification helpers

    static func parseHexColor(_ string: String) -> NSColor? {
        var hex = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard hex.count == 6 || hex.count == 3, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard let value = UInt32(hex, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static func isLink(_ string: String) -> Bool {
        guard !string.contains(" "), string.count < 2048 else { return false }
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}
