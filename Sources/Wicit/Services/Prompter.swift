import AppKit
import SwiftUI
import Combine

/// Teleprompter engine: owns the script text, scroll speed and the floating
/// always-on-top window the text scrolls in. Scrolling is driven by wall-clock
/// time (`offset(at:)`) so it is perfectly smooth and pause/resume-accurate.
final class Prompter: ObservableObject {
    static let shared = Prompter()

    @Published var text: String {
        didSet { UserDefaults.standard.set(text, forKey: "wicit.prompter.text") }
    }
    /// Scroll speed in points per second.
    @Published private(set) var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: "wicit.prompter.speed") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "wicit.prompter.fontSize") }
    }
    @Published private(set) var isRunning = false
    @Published private(set) var isWindowOpen = false

    private var baseOffset: Double = 0
    private var resumeDate = Date()
    private var windowController: PrompterWindowController?

    private init() {
        let defaults = UserDefaults.standard
        text = defaults.string(forKey: "wicit.prompter.text") ?? ""
        let storedSpeed = defaults.double(forKey: "wicit.prompter.speed")
        speed = storedSpeed > 0 ? storedSpeed : 40
        let storedFont = defaults.double(forKey: "wicit.prompter.fontSize")
        fontSize = storedFont > 0 ? storedFont : 24
    }

    // MARK: - Scroll math

    /// Current scroll offset in points.
    func offset(at date: Date) -> Double {
        baseOffset + (isRunning ? date.timeIntervalSince(resumeDate) * speed : 0)
    }

    func play() {
        guard !isRunning else { return }
        resumeDate = Date()
        isRunning = true
    }

    func pause() {
        guard isRunning else { return }
        baseOffset = offset(at: Date())
        isRunning = false
    }

    func togglePlayback() {
        isRunning ? pause() : play()
    }

    func restart() {
        baseOffset = 0
        resumeDate = Date()
    }

    /// Change speed without the scroll position jumping.
    func setSpeed(_ newSpeed: Double) {
        let now = Date()
        baseOffset = offset(at: now)
        resumeDate = now
        speed = min(200, max(5, newSpeed))
    }

    // MARK: - Window

    func openWindow(startPlaying: Bool = true) {
        if windowController == nil {
            windowController = PrompterWindowController(prompter: self)
        }
        windowController?.show()
        isWindowOpen = true
        restart()
        if startPlaying { play() } else { pause() }
    }

    func closeWindow() {
        pause()
        windowController?.hide()
        isWindowOpen = false
    }
}

/// Borderless, floating, all-Spaces panel hosting the scrolling text. Draggable
/// by its background and resizable from the edges.
final class PrompterWindowController {
    private let panel: NSPanel

    init(prompter: Prompter) {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 480, height: 220)
        // Default position: clear of the notch shelf (which sits above this
        // window's level and would cover it when expanded).
        let frame = NSRect(
            x: screen.midX - size.width / 2,
            y: screen.maxY - size.height - NotchLayout.openHeight - 90,
            width: size.width,
            height: size.height
        )

        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 280, height: 140)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Remember wherever the user drags/resizes it.
        panel.setFrameAutosaveName("WicitPrompterWindow")
        panel.setFrameUsingName("WicitPrompterWindow")

        let hosting = NSHostingView(rootView: PrompterWindowView(prompter: prompter))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
