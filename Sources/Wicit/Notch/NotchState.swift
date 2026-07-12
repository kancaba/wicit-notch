import SwiftUI
import Combine

/// Which content tab is visible in the expanded panel.
enum NotchTab: String, CaseIterable, Identifiable {
    case widgets
    case shelf
    case clipboard
    case timer
    case prompter
    case settings

    var id: String { rawValue }

    /// Tabs shown on the left side of the toolbar; settings lives on the right.
    static let mainTabs: [NotchTab] = [.widgets, .shelf, .clipboard, .timer, .prompter]

    var symbol: String {
        switch self {
        case .widgets: return "house.fill"
        case .shelf: return "tray.and.arrow.down.fill"
        case .clipboard: return "doc.on.doc.fill"
        case .timer: return "timer"
        case .prompter: return "scroll.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// A drop destination inside the Home panel.
enum DropTarget: Equatable {
    case airdrop
    case files
}

/// Observable UI state shared between the AppKit window controller and the
/// SwiftUI content hierarchy.
final class NotchState: ObservableObject {
    @Published var isOpen: Bool = false
    @Published var selectedTab: NotchTab = .widgets

    /// True while a file-drag session is over the panel. Drives auto-open and
    /// keeps the panel from collapsing mid-drag (when `onHover` can't fire).
    @Published var isDragging: Bool = false
    /// Which drop tile the drag is currently hovering, for highlighting.
    @Published var hoveredTarget: DropTarget?

    let metrics: NotchMetrics

    private var closeWorkItem: DispatchWorkItem?

    init(metrics: NotchMetrics) {
        self.metrics = metrics
    }

    /// Keep in sync with NotchWindowController's frame animation duration.
    static let animationDuration: TimeInterval = 0.22

    func open() {
        cancelPendingClose()
        guard !isOpen else { return }
        withAnimation(.easeOut(duration: Self.animationDuration)) {
            isOpen = true
        }
    }

    /// Collapses the panel unless a drag is in progress.
    func requestClose(after delay: TimeInterval = 0.25) {
        cancelPendingClose()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isDragging else { return }
            self.closeNow()
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelPendingClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }

    private func closeNow() {
        withAnimation(.easeOut(duration: Self.animationDuration)) {
            isOpen = false
        }
    }

    func toggle() {
        if isOpen { requestClose(after: 0) } else { open() }
    }
}
