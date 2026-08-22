import AppKit
import SwiftUI

/// A simple scale/offset-aware grid rendered behind the nodes, giving visual
/// feedback for pan and zoom on the otherwise-infinite canvas.
struct GridBackground: View {
    let transform: CanvasTransform

    private let baseSpacing: CGFloat = 50

    var body: some View {
        Canvas { context, size in
            let spacing = baseSpacing * transform.scale
            guard spacing > 4 else { return }

            let offsetX = transform.offset.x.truncatingRemainder(dividingBy: spacing)
            let offsetY = transform.offset.y.truncatingRemainder(dividingBy: spacing)

            var x = offsetX
            while x < size.width {
                let line = Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(line, with: .color(.gray.opacity(0.15)))
                x += spacing
            }

            var y = offsetY
            while y < size.height {
                let line = Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(line, with: .color(.gray.opacity(0.15)))
                y += spacing
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .allowsHitTesting(false)
    }
}
