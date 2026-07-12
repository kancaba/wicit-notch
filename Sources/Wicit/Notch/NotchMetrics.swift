import AppKit

/// Geometry of the physical notch (or a simulated one on non-notch displays),
/// derived entirely from public `NSScreen` APIs.
struct NotchMetrics {
    /// The screen this metric set was measured on.
    let screen: NSScreen
    /// Width of the notch cutout in points.
    let notchWidth: CGFloat
    /// Height of the notch cutout in points (top safe-area inset).
    let notchHeight: CGFloat
    /// Whether the display actually has a hardware notch.
    let hasHardwareNotch: Bool

    /// Fallback dimensions used when drawing on a display without a notch,
    /// so the app still works on external monitors and older MacBooks.
    private static let simulatedWidth: CGFloat = 220
    private static let simulatedHeight: CGFloat = 32

    static func current() -> NotchMetrics {
        let screen = preferredScreen()
        let inset = screen.safeAreaInsets.top

        if inset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // The notch spans the gap between the two auxiliary areas.
            let width = screen.frame.width - left.width - right.width
            return NotchMetrics(
                screen: screen,
                notchWidth: max(width, simulatedWidth),
                notchHeight: inset,
                hasHardwareNotch: true
            )
        }

        return NotchMetrics(
            screen: screen,
            notchWidth: simulatedWidth,
            notchHeight: simulatedHeight,
            hasHardwareNotch: false
        )
    }

    /// Prefer the display that has a notch; otherwise the main screen.
    private static func preferredScreen() -> NSScreen {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    /// Top-center point of the screen in AppKit (bottom-left origin) coordinates.
    var screenTopCenter: CGPoint {
        CGPoint(x: screen.frame.midX, y: screen.frame.maxY)
    }
}
