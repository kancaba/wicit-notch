import AppKit
import Combine

struct AppShortcut: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let icon: NSImage
}

/// App launcher tiles for the dashboard. Defaults to the user's Dock apps
/// (com.apple.dock persistent-apps); once the user customizes the grid, the
/// custom list is persisted and used instead.
final class AppShortcuts: ObservableObject {
    static let shared = AppShortcuts()

    @Published private(set) var apps: [AppShortcut] = []

    /// 2 columns × 3 rows in the dashboard grid.
    let maxApps = 6

    private static let customKey = "wicit.customApps"

    /// Non-nil once the user has customized the grid.
    private var customPaths: [String]? {
        get { UserDefaults.standard.stringArray(forKey: Self.customKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.customKey) }
    }

    private init() {
        reload()
    }

    func reload() {
        var urls: [URL]
        if let custom = customPaths {
            urls = custom.map { URL(fileURLWithPath: $0) }
        } else {
            urls = dockAppURLs()
            if urls.isEmpty { urls = Self.fallbackURLs }
        }
        apps = urls
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(maxApps)
            .map { url in
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 44, height: 44)
                let name = FileManager.default.displayName(atPath: url.path)
                return AppShortcut(url: url, name: name, icon: icon)
            }
    }

    func launch(_ app: AppShortcut) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init(), completionHandler: nil)
    }

    // MARK: - Customization

    func add(url: URL) {
        var paths = customPaths ?? apps.map(\.url.path)
        guard !paths.contains(url.path) else { return }
        paths.append(url.path)
        customPaths = Array(paths.prefix(maxApps))
        reload()
    }

    func remove(_ app: AppShortcut) {
        var paths = customPaths ?? apps.map(\.url.path)
        paths.removeAll { $0 == app.url.path }
        customPaths = paths
        reload()
    }

    /// Back to mirroring the Dock.
    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.customKey)
        reload()
    }

    // MARK: - Sources

    private func dockAppURLs() -> [URL] {
        guard let entries = UserDefaults(suiteName: "com.apple.dock")?
            .array(forKey: "persistent-apps") as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let tile = entry["tile-data"] as? [String: Any],
                  let file = tile["file-data"] as? [String: Any],
                  let urlString = file["_CFURLString"] as? String,
                  let url = URL(string: urlString) else { return nil }
            return url
        }
    }

    private static let fallbackURLs: [URL] = [
        "/Applications/Safari.app",
        "/System/Applications/Mail.app",
        "/System/Applications/Notes.app",
        "/System/Applications/Calendar.app",
        "/System/Applications/Music.app",
        "/System/Applications/Utilities/Terminal.app"
    ].map { URL(fileURLWithPath: $0) }
}
