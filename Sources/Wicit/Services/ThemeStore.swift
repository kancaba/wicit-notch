import SwiftUI
import Combine

/// A panel background theme. The top of the panel is always pure black so it
/// merges with the notch; the theme colors the lower body of the shelf.
struct NotchTheme: Identifiable, Equatable {
    let id: String
    let nameEN: String
    let nameTR: String
    /// Bottom gradient color the black fades into.
    let bottom: Color

    func name(_ loc: Localization) -> String {
        loc.isTurkish ? nameTR : nameEN
    }

    static let all: [NotchTheme] = [
        NotchTheme(id: "black", nameEN: "Black", nameTR: "Siyah",
                   bottom: Color(white: 0.08)),
        NotchTheme(id: "graphite", nameEN: "Graphite", nameTR: "Grafit",
                   bottom: Color(white: 0.17)),
        NotchTheme(id: "midnight", nameEN: "Midnight", nameTR: "Gece",
                   bottom: Color(red: 0.05, green: 0.09, blue: 0.22)),
        NotchTheme(id: "violet", nameEN: "Violet", nameTR: "Mor",
                   bottom: Color(red: 0.17, green: 0.07, blue: 0.24)),
        NotchTheme(id: "ocean", nameEN: "Ocean", nameTR: "Okyanus",
                   bottom: Color(red: 0.03, green: 0.16, blue: 0.18))
    ]

    static let fallback = all[0]

    static func by(id: String) -> NotchTheme {
        all.first { $0.id == id } ?? fallback
    }
}

/// Remembers a theme per Space and publishes the one for the active Space —
/// the "customization connected to Spaces" behavior from the reference design.
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var current: NotchTheme = .fallback
    /// Optional custom image drawn behind the open panel for this Space.
    @Published private(set) var backgroundImage: NSImage?

    private static let defaultsKey = "wicit.spaceThemes"
    private static let imagesKey = "wicit.spaceImages"

    /// spaceIndex (as String, for plist compatibility) → theme id.
    private var mapping: [String: String] {
        didSet { UserDefaults.standard.set(mapping, forKey: Self.defaultsKey) }
    }
    /// spaceIndex → image file path.
    private var imageMapping: [String: String] {
        didSet { UserDefaults.standard.set(imageMapping, forKey: Self.imagesKey) }
    }
    private var imageCache: [String: NSImage] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        mapping = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        imageMapping = UserDefaults.standard.dictionary(forKey: Self.imagesKey) as? [String: String] ?? [:]

        SpaceMonitor.shared.$spaceIndex
            .sink { [weak self] index in self?.apply(spaceIndex: index) }
            .store(in: &cancellables)
    }

    func select(_ theme: NotchTheme) {
        mapping[String(SpaceMonitor.shared.spaceIndex)] = theme.id
        current = theme
    }

    var hasBackgroundImage: Bool { backgroundImage != nil }

    /// Set (or clear, with nil) the background image for the active Space.
    func setBackgroundImage(path: String?) {
        let key = String(SpaceMonitor.shared.spaceIndex)
        if let path {
            imageMapping[key] = path
        } else {
            imageMapping.removeValue(forKey: key)
        }
        backgroundImage = loadImage(for: key)
    }

    private func apply(spaceIndex: Int) {
        let key = String(spaceIndex)
        let theme = NotchTheme.by(id: mapping[key] ?? NotchTheme.fallback.id)
        if current != theme { current = theme }
        backgroundImage = loadImage(for: key)
    }

    private func loadImage(for key: String) -> NSImage? {
        guard let path = imageMapping[key] else { return nil }
        if let cached = imageCache[path] { return cached }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        imageCache[path] = image
        return image
    }
}
