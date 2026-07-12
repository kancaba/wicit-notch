import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var notchController: NotchWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        setupNotch()
        // Start background services immediately so data is ready before the
        // panel is first opened.
        _ = ClipboardManager.shared
        _ = NowPlayingService.shared
        _ = WeatherService.shared
        // Ask for calendar access once, at first launch, instead of surprising
        // the user with a button inside the widget later.
        EventsService.shared.requestAccessIfNeeded()

        // Global ⌥+Space toggle.
        HotkeyManager.shared.onToggle = { [weak self] in
            self?.notchController?.toggle()
        }
        HotkeyManager.shared.register()

        // Rebuild the status menu when the language changes.
        Localization.shared.$language
            .dropFirst()
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Shut down helper processes.
        NowPlayingService.shared.stop()
        CaffeineService.shared.stop()
    }

    // MARK: - Main menu

    /// LSUIElement apps have no visible menu bar, but ⌘C/⌘V/⌘X/⌘A/⌘Z only
    /// work when an Edit menu exists in the main menu — key equivalents are
    /// routed through it. Without this, paste in text fields is dead.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Wicit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "Wicit"
            )
        }
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let loc = Localization.shared
        let menu = NSMenu()
        menu.addItem(
            withTitle: loc.t("Toggle Panel", "Paneli Aç/Kapat"),
            action: #selector(togglePanel),
            keyEquivalent: "t"
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: loc.t("Quit Wicit", "Wicit'ten Çık"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem?.menu = menu
    }

    @objc private func togglePanel() {
        notchController?.toggle()
    }

    // MARK: - Notch panel

    private func setupNotch() {
        let controller = NotchWindowController()
        controller.show()
        notchController = controller
    }
}
