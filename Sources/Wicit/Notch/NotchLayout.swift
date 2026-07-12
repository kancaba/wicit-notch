import AppKit

/// Shared geometry so the AppKit window sizing / drag routing and the SwiftUI
/// drawing agree. The overlay window is sized to exactly its content (a thin
/// catch strip when collapsed, the full panel when open) so everything outside
/// it stays naturally click-through — the window never covers the menu bar or
/// desktop beyond what it actually draws.
enum NotchLayout {
    /// Concave (inverse) radius where the top edge meets the side walls, giving
    /// the "grows out of the notch" corners.
    static func topRadius(isOpen: Bool) -> CGFloat {
        isOpen ? 14 : 8
    }

    /// Convex radius of the two bottom corners.
    static func bottomRadius(isOpen: Bool) -> CGFloat {
        isOpen ? 20 : 10
    }

    /// Dimensions of the expanded panel / open window — a wide, shallow shelf
    /// like the reference design.
    static let openWidth: CGFloat = 860
    static let openHeight: CGFloat = 292

    // Content layout inside the expanded panel (kept in sync with the SwiftUI
    // padding/spacing in NotchRootView + HomeView). Horizontal padding is kept
    // clearly larger than the wall inset (topRadius) so content never hugs the
    // curved side walls.
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 16
    static let toolbarHeight: CGFloat = 30
    static let toolbarSpacing: CGFloat = 12
    static let tileSpacing: CGFloat = 12

    static let openSize = CGSize(width: openWidth, height: openHeight)

    /// Width of the wings flanking the notch while media plays (mini artwork on
    /// the left, equalizer on the right).
    static let mediaSideWidth: CGFloat = 76

    /// Collapsed window: hugs the notch so it stays visually invisible while
    /// idle and only covers the (item-free) notch region of the menu bar. With
    /// media playing it grows symmetric wings for the mini player. It still
    /// catches drags and hovers heading toward the notch.
    static func closedSize(_ metrics: NotchMetrics, hasMedia: Bool = false) -> CGSize {
        let extra: CGFloat = hasMedia ? mediaSideWidth * 2 : 8
        // Exactly the notch height — anything taller shows as a black slab
        // hanging below the real notch.
        return CGSize(width: metrics.notchWidth + extra, height: metrics.notchHeight)
    }

    static func windowSize(isOpen: Bool, metrics: NotchMetrics, hasMedia: Bool = false) -> CGSize {
        isOpen ? openSize : closedSize(metrics, hasMedia: hasMedia)
    }

    /// The AirDrop / Files tile rects inside the open panel, in the (edge-to-edge)
    /// view's coordinate space, so an AppKit drop can be routed to the correct
    /// destination. `viewSize` is the open window/hosting-view size.
    static func tileRects(viewSize: CGSize) -> (airdrop: CGRect, files: CGRect) {
        let contentLeft = horizontalPadding
        let contentRight = viewSize.width - horizontalPadding
        let contentWidth = contentRight - contentLeft

        // Toolbar sits at the top of the panel; tiles fill the rest below it.
        let tilesTop = viewSize.height - topPadding - toolbarHeight - toolbarSpacing
        let tilesBottom = bottomPadding
        let tileWidth = (contentWidth - tileSpacing) / 2

        let airdrop = CGRect(
            x: contentLeft,
            y: tilesBottom,
            width: tileWidth,
            height: tilesTop - tilesBottom
        )
        let files = CGRect(
            x: contentLeft + tileWidth + tileSpacing,
            y: tilesBottom,
            width: tileWidth,
            height: tilesTop - tilesBottom
        )
        return (airdrop, files)
    }

    /// Which tile (if any) a point in view coordinates falls into.
    static func dropTarget(at point: CGPoint, viewSize: CGSize) -> DropTarget? {
        let rects = tileRects(viewSize: viewSize)
        if rects.airdrop.contains(point) { return .airdrop }
        if rects.files.contains(point) { return .files }
        return nil
    }
}
