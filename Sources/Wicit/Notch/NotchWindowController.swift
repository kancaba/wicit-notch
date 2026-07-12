import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Owns the borderless overlay panel anchored to the notch and bridges it to
/// the SwiftUI content. The window is resized to match its content so the area
/// around it stays click-through.
/// Borderless panels refuse key status by default, which makes SwiftUI buttons
/// swallow clicks — allow key (without ever becoming main / activating the app).
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class NotchWindowController {
    private let panel: NSPanel
    private let state: NotchState
    private var cancellables = Set<AnyCancellable>()
    private var mouseMonitors: [Any] = []

    init() {
        let metrics = NotchMetrics.current()
        self.state = NotchState(metrics: metrics)

        let closed = NotchLayout.closedSize(metrics)
        panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: closed),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        installContent()
        applyFrame(isOpen: false, animated: false)
        observeState()
        installHoverTracking()
    }

    deinit {
        mouseMonitors.forEach { NSEvent.removeMonitor($0) }
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // no drop shadow — keep it flush with the notch
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        // Sit above the menu bar so the panel can overlap the notch region.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
    }

    private func installContent() {
        let rootView = NotchRootView(state: state)
        let hostingView = NotchDragHostingView(rootView: rootView)
        hostingView.state = state
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    private func observeState() {
        // Re-frame when the panel opens/closes, media starts/stops or a timer
        // starts/ends — the collapsed strip grows wings for the mini display.
        let timerActive = Publishers.CombineLatest(
            CountdownTimer.shared.$remaining,
            CountdownTimer.shared.$isRunning
        )
        .map { $0 > 0 || $1 }
        .removeDuplicates()

        Publishers.CombineLatest3(
            state.$isOpen.removeDuplicates(),
            NowPlayingService.shared.$track.map { $0 != nil }.removeDuplicates(),
            timerActive
        )
        .sink { [weak self] isOpen, _, _ in
            self?.applyFrame(isOpen: isOpen, animated: true)
        }
        .store(in: &cancellables)
    }

    private var hasMedia: Bool {
        NowPlayingService.shared.track != nil || CountdownTimer.shared.isActive
    }

    /// Resize + reposition the window, keeping it centered under the notch with
    /// its top edge pinned to the top of the screen.
    private func applyFrame(isOpen: Bool, animated: Bool) {
        let metrics = state.metrics
        let screen = metrics.screen.frame
        let size = NotchLayout.windowSize(isOpen: isOpen, metrics: metrics, hasMedia: hasMedia)
        let frame = NSRect(
            x: screen.midX - size.width / 2,
            y: screen.maxY - size.height,
            width: size.width,
            height: size.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NotchState.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: false)
        }
    }

    // MARK: - Hover tracking

    /// Track hover in stable *screen* coordinates rather than via SwiftUI
    /// `.onHover`, whose events fire spuriously while the window resizes and
    /// caused open/close flicker. Hysteresis: open on touching the notch, stay
    /// open until the cursor leaves the whole panel.
    private func installHoverTracking() {
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.handleMouseMoved() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { handler($0) }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { event in
            handler(event)
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    private func handleMouseMoved() {
        // Drag sessions manage open/close themselves.
        guard !state.isDragging else { return }
        let location = NSEvent.mouseLocation
        if state.isOpen {
            openScreenRect.contains(location) ? state.open() : state.requestClose()
        } else if notchScreenRect.contains(location) {
            state.open()
        }
    }

    private var notchScreenRect: CGRect {
        let screen = state.metrics.screen.frame
        let size = NotchLayout.closedSize(state.metrics, hasMedia: hasMedia)
        return CGRect(x: screen.midX - size.width / 2, y: screen.maxY - size.height, width: size.width, height: size.height)
    }

    private var openScreenRect: CGRect {
        let screen = state.metrics.screen.frame
        return CGRect(
            x: screen.midX - NotchLayout.openWidth / 2,
            y: screen.maxY - NotchLayout.openHeight,
            width: NotchLayout.openWidth,
            height: NotchLayout.openHeight
        )
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func toggle() {
        state.toggle()
    }
}

/// Hosting view that acts as a drag destination: it opens the panel and routes
/// dropped files to AirDrop / Pocket — because `onHover` never fires during an
/// active drag session. Normal mouse click-through is handled by sizing the
/// window to its content, so no custom hit-testing is needed.
private final class NotchDragHostingView<Content: View>: NSHostingView<Content> {
    weak var state: NotchState?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Register the very first click even while the app is inactive.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func location(of sender: NSDraggingInfo) -> CGPoint {
        convert(sender.draggingLocation, from: nil)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let state else { return [] }
        state.isDragging = true
        // A file drag should reveal the drop targets, not whatever tab was open.
        state.selectedTab = .shelf
        state.open()
        updateHover(sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHover(sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        endDrag()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        endDrag()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let point = location(of: sender)
        let target = NotchLayout.dropTarget(at: point, viewSize: bounds.size)
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }

        switch target {
        case .airdrop:
            AirDropService.share(urls)
        case .files, .none:
            // Default any drop on the panel that isn't clearly AirDrop to Pocket.
            urls.forEach { FileShelf.shared.add($0) }
        }
        return true
    }

    private func updateHover(_ sender: NSDraggingInfo) {
        guard let state else { return }
        let point = location(of: sender)
        // While the window is still collapsing/expanding, bounds may be the
        // closed size; only classify tiles once we're at the open size.
        state.hoveredTarget = NotchLayout.dropTarget(at: point, viewSize: bounds.size)
    }

    private func endDrag() {
        guard let state else { return }
        state.isDragging = false
        state.hoveredTarget = nil
        state.requestClose(after: 0.15)
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return []
        }
        return items
    }
}
