import CoreGraphics

/// Manual model↔screen coordinate transform for the infinite canvas.
/// Deliberately not implemented via `.scaleEffect` on a giant `ZStack`,
/// which creates coordinate/hit-testing conflicts between a scaled container
/// and independent per-node drag gestures.
struct CanvasTransform: Equatable {
    var offset: CGPoint = .zero
    var scale: CGFloat = 1.0

    func toScreen(_ modelPoint: CGPoint) -> CGPoint {
        CGPoint(x: modelPoint.x * scale + offset.x, y: modelPoint.y * scale + offset.y)
    }

    func toModel(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: (screenPoint.x - offset.x) / scale, y: (screenPoint.y - offset.y) / scale)
    }

    /// Converts a screen-space drag delta into a model-space delta, keeping
    /// 1:1 cursor tracking on dragged nodes at any zoom level.
    func modelDelta(fromScreenDelta screenDelta: CGSize) -> CGSize {
        CGSize(width: screenDelta.width / scale, height: screenDelta.height / scale)
    }
}
