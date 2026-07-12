import AppKit
import Combine

/// A dropped item held on the "Pocket" shelf, backed by a copy in a temp dir
/// so the item survives even if the source is moved or deleted.
struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let displayName: String
    let icon: NSImage

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool { lhs.id == rhs.id }
}

/// The "Pocket" — a temporary file shelf (Yoink/Dropover style). Files dropped
/// here are copied into a session temp directory and can be dragged back out.
final class FileShelf: ObservableObject {
    static let shared = FileShelf()

    @Published private(set) var items: [ShelfItem] = []

    private let directory: URL

    private init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WicitPocket", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func add(_ sourceURL: URL) {
        let destination = uniqueDestination(for: sourceURL.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            // If the copy fails (e.g. permissions), fall back to referencing
            // the original so the drop is never silently lost.
            appendItem(for: sourceURL)
            return
        }
        appendItem(for: destination)
    }

    func remove(_ item: ShelfItem) {
        try? FileManager.default.removeItem(at: item.url)
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        for item in items {
            try? FileManager.default.removeItem(at: item.url)
        }
        items.removeAll()
    }

    // MARK: - Helpers

    private func appendItem(for url: URL) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 48, height: 48)
        items.append(
            ShelfItem(url: url, displayName: url.lastPathComponent, icon: icon)
        )
    }

    private func uniqueDestination(for name: String) -> URL {
        var candidate = directory.appendingPathComponent(name)
        var counter = 1
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
}
