import AppKit

/// A single captured clipboard entry.
struct ClipItem: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case text
        case link
        case color
        case image
        case file
    }

    var id = UUID()
    let kind: Kind
    let date: Date

    /// Plain-text payload (text/link/color hex/file path).
    var text: String?
    /// Image payload (image kind).
    var image: NSImage?
    /// Parsed color (color kind).
    var color: NSColor?
    /// File URLs (file kind).
    var fileURLs: [URL] = []

    /// Name / icon / bundle id of the app that was frontmost when captured.
    var sourceName: String?
    var sourceIcon: NSImage?
    var sourceBundleID: String?

    var isFavorite: Bool = false

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool { lhs.id == rhs.id }

    /// A short label describing the content, used for accessibility / previews.
    var previewText: String {
        switch kind {
        case .text, .link: return text ?? ""
        case .color: return text ?? ""
        case .image: return "Image"
        case .file: return fileURLs.first?.lastPathComponent ?? "File"
        }
    }
}

extension Date {
    /// Compact relative age like the reference UI: "55s", "6m", "1h", "1d".
    func shortRelativeAgo(to now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(self)))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
