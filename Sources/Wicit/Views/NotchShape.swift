import SwiftUI

/// The signature notch-shelf outline: the top edge is flush and full-width, then
/// concave (inverse-radius) fillets on the top-left / top-right sweep the walls
/// inward, and the bottom corners are normal convex rounds. This makes the panel
/// read as a seamless downward extension of the physical notch.
struct NotchShape: Shape {
    /// Inverse (concave) radius where the top edge meets each side wall.
    var topRadius: CGFloat
    /// Convex radius of the two bottom corners.
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = min(topRadius, rect.width / 2, rect.height / 2)
        let br = min(bottomRadius, rect.width / 2 - tr, rect.height / 2)

        // Top-left corner, flush with the screen edge.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Concave fillet: top edge → left wall.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            control: CGPoint(x: rect.minX + tr, y: rect.minY)
        )

        // Left wall down to the bottom-left convex corner.
        path.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
            control: CGPoint(x: rect.minX + tr, y: rect.maxY)
        )

        // Bottom edge to the bottom-right convex corner.
        path.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
            control: CGPoint(x: rect.maxX - tr, y: rect.maxY)
        )

        // Right wall up to the concave top-right fillet.
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tr, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
