import CoreGraphics
import SwiftUI

/// Derives a parent-bottom → child-top bezier curve (plus its label
/// midpoint) from two node frames collected via `NodeFramePreferenceKey`.
struct EdgeGeometry {
    let start: CGPoint
    let end: CGPoint
    let midpoint: CGPoint

    init(parentFrame: CGRect, childFrame: CGRect) {
        start = CGPoint(x: parentFrame.midX, y: parentFrame.maxY)
        end = CGPoint(x: childFrame.midX, y: childFrame.minY)
        midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }

    var path: Path {
        Path { path in
            path.move(to: start)
            let controlOffset = max(40, abs(end.y - start.y) / 2)
            let control1 = CGPoint(x: start.x, y: start.y + controlOffset)
            let control2 = CGPoint(x: end.x, y: end.y - controlOffset)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
    }
}
