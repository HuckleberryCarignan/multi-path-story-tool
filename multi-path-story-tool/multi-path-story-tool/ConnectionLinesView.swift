import SwiftUI

struct ConnectionLinesView: View {
    var vm: StoryViewModel
    var canvasOffset: CGSize
    var dragOffsets: [UUID: CGSize] = [:]

    var body: some View {
        let connections = vm.connections
        let nodes = vm.nodes
        let selectedID = vm.selectedConnectionID

        ZStack {
            // Visual layer
            Canvas { ctx, _ in
                for conn in connections {
                    guard let (rawFrom, rawTo) = endpoints(conn, nodes: nodes) else { continue }

                    let from = CGPoint(x: rawFrom.x + canvasOffset.width,  y: rawFrom.y + canvasOffset.height)
                    let to   = CGPoint(x: rawTo.x   + canvasOffset.width,  y: rawTo.y   + canvasOffset.height)
                    let cp1  = CGPoint(x: from.x, y: from.y + curveStrength)
                    let cp2  = CGPoint(x: to.x,   y: to.y   - curveStrength)

                    var path = Path()
                    path.move(to: from)
                    path.addCurve(to: to, control1: cp1, control2: cp2)

                    let isSelected = selectedID == conn.id
                    let baseColor  = pastelColors[conn.colorIndex % pastelColors.count]
                    let crosses    = !conn.isOrphaned && nodesCrossing(rawFrom, rawTo,
                                        excludeIDs: [conn.fromNodeID, conn.toNodeID], nodes: nodes)

                    // Selection halo drawn behind the line
                    if isSelected {
                        ctx.stroke(path, with: .color(.white.opacity(0.9)),
                                   style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        ctx.stroke(path, with: .color(.accentColor.opacity(0.45)),
                                   style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    }

                    if conn.isOrphaned {
                        ctx.stroke(path, with: .color(.red),
                                   style: StrokeStyle(lineWidth: isSelected ? 4 : 3, lineCap: .round))
                        drawArrowHead(ctx: ctx, tip: to, approach: cp2, color: .red)
                    } else if crosses {
                        ctx.stroke(path, with: .color(baseColor.opacity(0.55)),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 5]))
                        drawArrowHead(ctx: ctx, tip: to, approach: cp2, color: baseColor.opacity(0.55))
                    } else {
                        ctx.stroke(path, with: .color(baseColor),
                                   style: StrokeStyle(lineWidth: isSelected ? 3.5 : 2.5, lineCap: .round))
                        drawArrowHead(ctx: ctx, tip: to, approach: cp2, color: baseColor)
                    }
                }
            }
            .allowsHitTesting(false)

            // Hit-detection layer — invisible wide strokes, one per connection
            ForEach(connections) { conn in
                ConnectionHitPath(conn: conn, nodes: nodes, canvasOffset: canvasOffset, dragOffsets: dragOffsets, vm: vm)
            }
        }
    }

    private func endpoints(_ conn: NodeConnection, nodes: [StoryNode]) -> (CGPoint, CGPoint)? {
        let fromNode = nodes.first { $0.id == conn.fromNodeID }
        let toNode   = nodes.first { $0.id == conn.toNodeID }

        if conn.isOrphaned {
            let from = conn.orphanedFromPos ?? fromNode?.bottomCenter ?? .zero
            let to   = conn.orphanedToPos   ?? toNode?.topCenter     ?? .zero
            return (from, to)
        }
        guard let f = fromNode, let t = toNode else { return nil }
        let fd = dragOffsets[f.id] ?? .zero
        let td = dragOffsets[t.id] ?? .zero
        return (
            CGPoint(x: f.bottomCenter.x + fd.width, y: f.bottomCenter.y + fd.height),
            CGPoint(x: t.topCenter.x    + td.width, y: t.topCenter.y    + td.height)
        )
    }

    private func nodesCrossing(_ from: CGPoint, _ to: CGPoint,
                               excludeIDs: Set<UUID>, nodes: [StoryNode]) -> Bool {
        let cp1 = CGPoint(x: from.x, y: from.y + curveStrength)
        let cp2 = CGPoint(x: to.x,   y: to.y   - curveStrength)
        for tVal in stride(from: CGFloat(0.15), through: 0.85, by: 0.1) {
            let mt = 1 - tVal
            let x = mt*mt*mt*from.x + 3*mt*mt*tVal*cp1.x + 3*mt*tVal*tVal*cp2.x + tVal*tVal*tVal*to.x
            let y = mt*mt*mt*from.y + 3*mt*mt*tVal*cp1.y + 3*mt*tVal*tVal*cp2.y + tVal*tVal*tVal*to.y
            for node in nodes where !excludeIDs.contains(node.id) {
                if node.rect.insetBy(dx: 2, dy: 2).contains(CGPoint(x: x, y: y)) { return true }
            }
        }
        return false
    }

    private func drawArrowHead(ctx: GraphicsContext, tip: CGPoint, approach: CGPoint, color: Color) {
        let angle  = atan2(tip.y - approach.y, tip.x - approach.x)
        let len: CGFloat    = 10
        let spread: CGFloat = .pi / 6

        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - len * cos(angle - spread),
                                  y: tip.y - len * sin(angle - spread)))
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - len * cos(angle + spread),
                                  y: tip.y - len * sin(angle + spread)))
        ctx.stroke(arrow, with: .color(color),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

// Invisible wide bezier used purely for tap hit-testing
struct ConnectionHitPath: View {
    let conn: NodeConnection
    let nodes: [StoryNode]
    let canvasOffset: CGSize
    let dragOffsets: [UUID: CGSize]
    var vm: StoryViewModel

    var body: some View {
        if let (rawFrom, rawTo) = resolvedEndpoints {
            let from = CGPoint(x: rawFrom.x + canvasOffset.width,  y: rawFrom.y + canvasOffset.height)
            let to   = CGPoint(x: rawTo.x   + canvasOffset.width,  y: rawTo.y   + canvasOffset.height)
            let cp1  = CGPoint(x: from.x, y: from.y + curveStrength)
            let cp2  = CGPoint(x: to.x,   y: to.y   - curveStrength)

            Path { p in
                p.move(to: from)
                p.addCurve(to: to, control1: cp1, control2: cp2)
            }
            .stroke(Color.primary.opacity(0.001), lineWidth: 20)
            .onTapGesture {
                vm.selectedConnectionID = conn.id
                vm.selectedNodeID = nil
            }
        }
    }

    private var resolvedEndpoints: (CGPoint, CGPoint)? {
        let fromNode = nodes.first { $0.id == conn.fromNodeID }
        let toNode   = nodes.first { $0.id == conn.toNodeID }
        if conn.isOrphaned {
            let from = conn.orphanedFromPos ?? fromNode?.bottomCenter ?? .zero
            let to   = conn.orphanedToPos   ?? toNode?.topCenter     ?? .zero
            return (from, to)
        }
        guard let f = fromNode, let t = toNode else { return nil }
        let fd = dragOffsets[f.id] ?? .zero
        let td = dragOffsets[t.id] ?? .zero
        return (
            CGPoint(x: f.bottomCenter.x + fd.width, y: f.bottomCenter.y + fd.height),
            CGPoint(x: t.topCenter.x    + td.width, y: t.topCenter.y    + td.height)
        )
    }
}
