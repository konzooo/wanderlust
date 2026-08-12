//
//  BrandMarks.swift
//  DesignSystem
//
//  The Wanderlust pin and plane as real vector geometry rather than a flat
//  `AppIcon` bitmap, so they stay crisp at any scale and can be stroked, masked
//  or animated — which is what any splash beyond "fade the PNG in" needs.
//
//  Everything is drawn in a unit square and scaled by the caller, so a mark is
//  resolution-independent and composes at any size.
//

import SwiftUI

// MARK: - Pin

/// The app icon's map pin: a circle with a tangent taper down to a point.
///
/// The taper is built from the true tangent lines to the circle, so the join is
/// smooth at any radius instead of the kinked "teardrop" you get from eyeballed
/// control points.
public struct PinShape: Shape {
    /// Circle radius as a fraction of the shape's width.
    public var headRadius: CGFloat

    public init(headRadius: CGFloat = 0.38) {
        self.headRadius = headRadius
    }

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = w * headRadius
        let centre = CGPoint(x: rect.midX, y: rect.minY + r)
        let tip = CGPoint(x: rect.midX, y: rect.minY + h)

        let d = tip.y - centre.y
        // Guard the degenerate case where the tip sits inside the head.
        guard d > r else {
            return Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r,
                                          width: r * 2, height: r * 2))
        }

        // Angle between "straight down" and the tangent point, measured at the
        // circle's centre.
        let spread = Angle.radians(acos(Double(r / d)))
        let down = Angle.degrees(90)
        let start = down + spread          // right-hand tangent point
        let end = down - spread            // left-hand tangent point

        var path = Path()
        path.addArc(center: centre, radius: r,
                    startAngle: start, endAngle: end,
                    clockwise: false)      // the long way, over the top
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }
}

// MARK: - Plane

/// The swept-wing plane that sits inside the pin, nose pointing up.
///
/// Drawn symmetrically from a half-profile so the two sides can never drift
/// apart when the proportions are tweaked.
public struct PlaneShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        // Right-hand half, from the nose down to the tail notch, in unit space.
        let half: [CGPoint] = [
            CGPoint(x: 0.50, y: 0.00),   // nose
            CGPoint(x: 0.57, y: 0.34),   // fuselage shoulder
            CGPoint(x: 1.00, y: 0.62),   // wingtip
            CGPoint(x: 1.00, y: 0.72),   // wing trailing edge
            CGPoint(x: 0.57, y: 0.60),   // wing root
            CGPoint(x: 0.55, y: 0.86),   // tailplane leading edge
            CGPoint(x: 0.70, y: 0.97),   // tailplane tip
            CGPoint(x: 0.70, y: 1.00),
            CGPoint(x: 0.50, y: 0.93)    // tail centre
        ]

        func point(_ p: CGPoint, mirrored: Bool) -> CGPoint {
            let x = mirrored ? 1 - p.x : p.x
            return CGPoint(x: rect.minX + x * rect.width,
                           y: rect.minY + p.y * rect.height)
        }

        var path = Path()
        path.move(to: point(half[0], mirrored: false))
        for p in half.dropFirst() { path.addLine(to: point(p, mirrored: false)) }
        for p in half.reversed().dropFirst() { path.addLine(to: point(p, mirrored: true)) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Composite marks

/// Pin + plane, coloured like the app icon. The plane is punched out of the pin
/// so the backdrop shows through, which keeps it crisp against the aurora.
public struct PinPlaneMark: View {
    public var size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        PinShape()
            .fill(
                LinearGradient(
                    colors: [Color.appTint, Color(hex: "#8B6BF6")],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                PlaneShape()
                    .fill(Color.white)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .rotationEffect(.degrees(45))
                    .padding(.top, size * 0.18)
            }
            .compositingGroup()
            .frame(width: size, height: size * 1.18)
    }
}

#if DEBUG
#Preview("Marks") {
    VStack(spacing: 40) {
        PinPlaneMark(size: 90)
        PlaneShape().fill(Color.appTint).frame(width: 60, height: 60)
        PinShape().stroke(Color.appTint, lineWidth: 2).frame(width: 60, height: 71)
    }
    .padding()
}
#endif
