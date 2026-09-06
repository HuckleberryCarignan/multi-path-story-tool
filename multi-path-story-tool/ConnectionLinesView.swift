import SwiftUI

private let routingBuffer: CGFloat = 10
private let sideMargin:    CGFloat = 50
private let bridgeRadius:  CGFloat = 7

// Which face of a node a connection touches (exit from source, entry into target).
private enum Port: CaseIterable {
    case top, bottom, left, right

    // Unit vector pointing AWAY from the node face.
    var dx: CGFloat { self == .left ? -1 : self == .right ?  1 : 0 }
    var dy: CGFloat { self == .top  ? -1 : self == .bottom ? 1 : 0 }

    func portCenter(of node: StoryNode, offset: CGSize = .zero, scale: CGFloat = 1) -> CGPoint {
        let px = node.position.x + offset.width  / scale
        let py = node.position.y + offset.height / scale
        switch self {
        case .top:    return CGPoint(x: px + nodeWidth  / 2, y: py)
        case .bottom: return CGPoint(x: px + nodeWidth  / 2, y: py + nodeHeight)
        case .left:   return CGPoint(x: px,                  y: py + nodeHeight / 2)
        case .right:  return CGPoint(x: px + nodeWidth,      y: py + nodeHeight / 2)
        }
    }
}

private struct PortAssignment {
    let from:      CGPoint
    let to:        CGPoint
    let exitPort:  Port
    let entryPort: Port
}

private struct ConnPathData {
    let path: Path
    let color: Color
    let isSelected: Bool
    let approach: CGPoint
    let tip: CGPoint
    let samples: [CGPoint]
}

// Assigns each connection its (exitPort, entryPort) pair.
// Rules:
//   • A side already used as an ENTRY on a node is locked — no further entries there.
//   • A side may not be used as an EXIT on a node if another connection is already
//     entering through that same side (visual conflict at the same port).
// Processing order: natural (creation) order of connections — stable across frames.
// For each connection the cheapest non-conflicting port pair (by port-center distance) wins.
private func computePortAssignments(
    connections:  [NodeConnection],
    nodes:        [StoryNode],
    dragOffsets:  [UUID: CGSize],
    canvasScale:  CGFloat
) -> [UUID: PortAssignment] {
    let s = canvasScale
    func offset(_ id: UUID) -> CGSize { dragOffsets[id] ?? .zero }

    var result    = [UUID: PortAssignment]()
    var entryUsed = [UUID: Set<Port>]()   // nodeID → ports locked as entry

    for conn in connections {
        if conn.isOrphaned {
            let from = conn.orphanedFromPos
                ?? nodes.first { $0.id == conn.fromNodeID }?.bottomCenter ?? .zero
            let to   = conn.orphanedToPos
                ?? nodes.first { $0.id == conn.toNodeID  }?.topCenter    ?? .zero
            result[conn.id] = PortAssignment(from: from, to: to,
                                              exitPort: .bottom, entryPort: .top)
            continue
        }
        guard let src = nodes.first(where: { $0.id == conn.fromNodeID }),
              let dst = nodes.first(where: { $0.id == conn.toNodeID }) else { continue }

        let fo = offset(src.id), to_ = offset(dst.id)
        let blockedExit  = entryUsed[src.id] ?? []  // sides where others enter src
        let blockedEntry = entryUsed[dst.id] ?? []  // sides already used as entry on dst

        var best: (exit: Port, entry: Port, dist: CGFloat)? = nil
        for ep in Port.allCases where !blockedExit.contains(ep) {
            let fromPt = ep.portCenter(of: src, offset: fo, scale: s)
            for np in Port.allCases where !blockedEntry.contains(np) {
                let toPt = np.portCenter(of: dst, offset: to_, scale: s)
                let d    = hypot(toPt.x - fromPt.x, toPt.y - fromPt.y)
                if best == nil || d < best!.dist { best = (ep, np, d) }
            }
        }
        guard let chosen = best else { continue }

        entryUsed[dst.id, default: []].insert(chosen.entry)
        result[conn.id] = PortAssignment(
            from:      chosen.exit.portCenter(of: src, offset: fo,  scale: s),
            to:        chosen.entry.portCenter(of: dst, offset: to_, scale: s),
            exitPort:  chosen.exit,
            entryPort: chosen.entry
        )
    }
    return result
}

// MARK: - Visual layer

struct ConnectionLinesView: View {
    var vm: StoryViewModel
    var canvasOffset: CGSize
    var dragOffsets: [UUID: CGSize] = [:]
    var canvasScale: CGFloat = 1.0

    var body: some View {
        let connections  = vm.connections
        let nodes        = vm.nodes
        let selectedID   = vm.selectedConnectionID
        let offset       = canvasOffset
        let drags        = dragOffsets
        let scale        = canvasScale

        Canvas { ctx, _ in
            let assignments = computePortAssignments(
                connections: connections, nodes: nodes,
                dragOffsets: drags, canvasScale: scale
            )
            let xform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                          tx: offset.width, ty: offset.height)

            // Phase 1: build all routed paths and sample them for crossing detection
            var allPaths: [ConnPathData] = []
            for conn in connections {
                guard let pa = assignments[conn.id] else { continue }
                let excludeIDs: Set<UUID> = [conn.fromNodeID, conn.toNodeID]
                let (canvasPath, canvasApproach) = routedPath(
                    rawFrom: pa.from, rawTo: pa.to,
                    exitPort: pa.exitPort, entryPort: pa.entryPort,
                    excludeIDs: excludeIDs, nodes: nodes
                )
                let path = canvasPath.applying(xform)
                // Tip is just outside the entry face (same formula as `end` in routedPath)
                let tipWorld = CGPoint(x: pa.to.x + pa.entryPort.dx * routingBuffer,
                                      y: pa.to.y + pa.entryPort.dy * routingBuffer)
                let tip      = tipWorld.applying(xform)
                let approach = canvasApproach.applying(xform)
                let isSelected = selectedID == conn.id
                let color: Color = conn.isOrphaned
                    ? .red
                    : pastelColors[conn.colorIndex % pastelColors.count]
                allPaths.append(ConnPathData(
                    path: path, color: color, isSelected: isSelected,
                    approach: approach, tip: tip, samples: samplePath(path)
                ))
            }

            // Phase 2: find crossings — record gap centres for the "under" path
            var underGaps: [Int: [CGPoint]] = [:]
            if allPaths.count >= 2 {
                for i in 0..<allPaths.count {
                    for j in (i + 1)..<allPaths.count {
                        for pt in findIntersections(allPaths[i].samples, allPaths[j].samples) {
                            underGaps[i, default: []].append(pt)
                        }
                    }
                }
            }

            // Phase 3: draw each path; stamp bridge knockouts where it goes "under"
            let bgColor = Color(nsColor: .windowBackgroundColor)
            for (i, pd) in allPaths.enumerated() {
                if pd.isSelected {
                    ctx.stroke(pd.path, with: .color(.white.opacity(0.9)),
                               style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    ctx.stroke(pd.path, with: .color(.accentColor.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 8, lineCap: .round))
                }
                ctx.stroke(pd.path, with: .color(pd.color),
                           style: StrokeStyle(lineWidth: pd.isSelected ? 3.5 : 2.5, lineCap: .round))
                drawArrowHead(ctx: ctx, tip: pd.tip, approach: pd.approach, color: pd.color)

                if let gaps = underGaps[i] {
                    let r = bridgeRadius
                    for pt in gaps {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                   width: r * 2, height: r * 2)),
                            with: .color(bgColor)
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Path sampling & intersection detection

    private func samplePath(_ path: Path) -> [CGPoint] {
        var result: [CGPoint] = []
        var current = CGPoint.zero
        path.cgPath.applyWithBlock { ptr in
            let elem = ptr.pointee
            switch elem.type {
            case .moveToPoint:
                current = elem.points[0]
            case .addLineToPoint:
                let end = elem.points[0]
                for k in 0..<10 {
                    let t = CGFloat(k) / 10
                    result.append(CGPoint(x: current.x + t * (end.x - current.x),
                                          y: current.y + t * (end.y - current.y)))
                }
                current = end
            case .addCurveToPoint:
                let cp1 = elem.points[0], cp2 = elem.points[1], end = elem.points[2]
                for k in 0..<20 {
                    let t = CGFloat(k) / 20, mt = 1 - t
                    result.append(CGPoint(
                        x: mt*mt*mt*current.x + 3*mt*mt*t*cp1.x + 3*mt*t*t*cp2.x + t*t*t*end.x,
                        y: mt*mt*mt*current.y + 3*mt*mt*t*cp1.y + 3*mt*t*t*cp2.y + t*t*t*end.y
                    ))
                }
                current = end
            default: break
            }
        }
        result.append(current)
        return result
    }

    private func findIntersections(_ a: [CGPoint], _ b: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0..<(a.count - 1) {
            for j in 0..<(b.count - 1) {
                guard let pt = segmentIntersect(a[i], a[i+1], b[j], b[j+1]) else { continue }
                if !result.contains(where: { hypot($0.x - pt.x, $0.y - pt.y) < 20 }) {
                    result.append(pt)
                }
            }
        }
        return result
    }

    private func segmentIntersect(_ p1: CGPoint, _ p2: CGPoint,
                                   _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        let dx1 = p2.x - p1.x, dy1 = p2.y - p1.y
        let dx2 = p4.x - p3.x, dy2 = p4.y - p3.y
        let denom = dx1 * dy2 - dy1 * dx2
        guard abs(denom) > 1e-6 else { return nil }
        let t = ((p3.x - p1.x) * dy2 - (p3.y - p1.y) * dx2) / denom
        let u = ((p3.x - p1.x) * dy1 - (p3.y - p1.y) * dx1) / denom
        guard t > 0.01 && t < 0.99 && u > 0.01 && u < 0.99 else { return nil }
        return CGPoint(x: p1.x + t * dx1, y: p1.y + t * dy1)
    }

    // MARK: - Routing

    // Builds a bezier that departs in the exit-port direction and arrives in the
    // entry-port direction, using the port's unit vector to drive both the buffer
    // step and the control-point offset.
    private func routedPath(rawFrom: CGPoint, rawTo: CGPoint,
                             exitPort: Port, entryPort: Port,
                             excludeIDs: Set<UUID>,
                             nodes: [StoryNode]) -> (path: Path, approach: CGPoint) {
        let buf   = routingBuffer
        let start = CGPoint(x: rawFrom.x + exitPort.dx  * buf,
                            y: rawFrom.y + exitPort.dy  * buf)
        let end   = CGPoint(x: rawTo.x   + entryPort.dx * buf,
                            y: rawTo.y   + entryPort.dy * buf)
        let cp1   = CGPoint(x: start.x + exitPort.dx  * curveStrength,
                            y: start.y + exitPort.dy  * curveStrength)
        let cp2   = CGPoint(x: end.x   + entryPort.dx * curveStrength,
                            y: end.y   + entryPort.dy * curveStrength)

        // Bottom→top inverted: source exit is at or below target entry.
        // Route around the rightmost node edge instead of looping back.
        if exitPort == .bottom && entryPort == .top && start.y >= end.y - buf {
            return sideRoutedPath(start: start, end: end,
                                  excludeIDs: excludeIDs, nodes: nodes, buf: buf)
        }

        // Bottom→top normal: avoid intermediate nodes that block the direct curve.
        if exitPort == .bottom && entryPort == .top {
            let blockers = crossedRects(from: start, to: end, cp1: cp1, cp2: cp2,
                                        excludeIDs: excludeIDs, nodes: nodes, buffer: buf)
            if !blockers.isEmpty {
                let blockRect = blockers.dropFirst().reduce(blockers[0]) { $0.union($1) }
                let midX   = (start.x + end.x) / 2
                let leftX  = blockRect.minX - buf
                let rightX = blockRect.maxX + buf
                let sideX  = abs(leftX - midX) <= abs(rightX - midX) ? leftX : rightX
                return waypointPath(start: start, end: end, sideX: sideX)
            }
        }

        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: cp1, control2: cp2)
        return (path, cp2)
    }

    // Routes around the right side of both nodes for the inverted bottom→top case.
    private func sideRoutedPath(start: CGPoint, end: CGPoint,
                                excludeIDs: Set<UUID>, nodes: [StoryNode],
                                buf: CGFloat) -> (path: Path, approach: CGPoint) {
        let excluded  = nodes.filter { excludeIDs.contains($0.id) }
        let rightEdge = (excluded.map { $0.position.x + nodeWidth }.max() ?? start.x) + sideMargin
        let allRight  = (nodes.map    { $0.position.x + nodeWidth }.max() ?? start.x) + sideMargin
        let sideX     = max(rightEdge, allRight)

        let wp1   = CGPoint(x: sideX, y: start.y)
        let wp2   = CGPoint(x: sideX, y: end.y)
        let dy    = wp1.y - wp2.y
        let s1cp1 = CGPoint(x: start.x + (sideX - start.x) * 0.4, y: start.y + 8)
        let s1cp2 = CGPoint(x: sideX - 10, y: start.y)
        let s2cp1 = CGPoint(x: sideX, y: wp1.y - dy * 0.33)
        let s2cp2 = CGPoint(x: sideX, y: wp2.y + dy * 0.33)
        let s3cp1 = CGPoint(x: sideX - 10, y: end.y)
        let s3cp2 = CGPoint(x: end.x + (sideX - end.x) * 0.4, y: end.y - 8)

        var path = Path()
        path.move(to: start)
        path.addCurve(to: wp1, control1: s1cp1, control2: s1cp2)
        path.addCurve(to: wp2, control1: s2cp1, control2: s2cp2)
        path.addCurve(to: end, control1: s3cp1, control2: s3cp2)
        return (path, s3cp2)
    }

    private func waypointPath(start: CGPoint, end: CGPoint,
                              sideX: CGFloat) -> (path: Path, approach: CGPoint) {
        let wp    = CGPoint(x: sideX, y: (start.y + end.y) / 2)
        let cp1a  = CGPoint(x: start.x, y: start.y + curveStrength * 0.6)
        let cp2a  = CGPoint(x: sideX,   y: wp.y    - curveStrength * 0.6)
        let cp1b  = CGPoint(x: sideX,   y: wp.y    + curveStrength * 0.6)
        let cp2b  = CGPoint(x: end.x,   y: end.y   - curveStrength * 0.6)
        var path  = Path()
        path.move(to: start)
        path.addCurve(to: wp,  control1: cp1a, control2: cp2a)
        path.addCurve(to: end, control1: cp1b, control2: cp2b)
        return (path, cp2b)
    }

    private func crossedRects(from: CGPoint, to: CGPoint,
                               cp1: CGPoint, cp2: CGPoint,
                               excludeIDs: Set<UUID>,
                               nodes: [StoryNode],
                               buffer: CGFloat) -> [CGRect] {
        let samples = bezierSamples(from: from, to: to, cp1: cp1, cp2: cp2)
        return nodes.compactMap { node -> CGRect? in
            guard !excludeIDs.contains(node.id) else { return nil }
            let inflated = node.rect.insetBy(dx: -buffer, dy: -buffer)
            return samples.contains { inflated.contains($0) } ? inflated : nil
        }
    }

    private func bezierSamples(from: CGPoint, to: CGPoint,
                                cp1: CGPoint, cp2: CGPoint) -> [CGPoint] {
        stride(from: CGFloat(0.05), through: 0.95, by: 0.05).map { t in
            let mt = 1 - t
            return CGPoint(
                x: mt*mt*mt*from.x + 3*mt*mt*t*cp1.x + 3*mt*t*t*cp2.x + t*t*t*to.x,
                y: mt*mt*mt*from.y + 3*mt*mt*t*cp1.y + 3*mt*t*t*cp2.y + t*t*t*to.y
            )
        }
    }

    // MARK: - Arrow head

    private func drawArrowHead(ctx: GraphicsContext, tip: CGPoint, approach: CGPoint, color: Color) {
        let angle    = atan2(tip.y - approach.y, tip.x - approach.x)
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

// MARK: - Hit detection

// Invisible wide strokes placed BEFORE node cards so node taps take priority.
struct ConnectionHitLayer: View {
    var vm: StoryViewModel
    var canvasOffset: CGSize
    var dragOffsets: [UUID: CGSize] = [:]
    var canvasScale: CGFloat = 1.0

    var body: some View {
        let connections = vm.connections
        let nodes       = vm.nodes
        let assignments = computePortAssignments(
            connections: connections, nodes: nodes,
            dragOffsets: dragOffsets, canvasScale: canvasScale
        )
        ForEach(connections) { conn in
            if let pa = assignments[conn.id] {
                ConnectionHitPath(conn: conn, portAssignment: pa,
                                  canvasOffset: canvasOffset, canvasScale: canvasScale, vm: vm)
            }
        }
    }
}

private struct ConnectionHitPath: View {
    let conn:           NodeConnection
    let portAssignment: PortAssignment
    let canvasOffset:   CGSize
    let canvasScale:    CGFloat
    var vm:             StoryViewModel

    var body: some View {
        let xform = CGAffineTransform(a: canvasScale, b: 0, c: 0, d: canvasScale,
                                      tx: canvasOffset.width, ty: canvasOffset.height)
        let from  = portAssignment.from.applying(xform)
        let to    = portAssignment.to.applying(xform)
        let ep    = portAssignment.exitPort
        let np    = portAssignment.entryPort
        let cs    = curveStrength * canvasScale
        let cp1   = CGPoint(x: from.x + ep.dx * cs, y: from.y + ep.dy * cs)
        let cp2   = CGPoint(x: to.x   + np.dx * cs, y: to.y   + np.dy * cs)

        Path { p in
            p.move(to: from)
            p.addCurve(to: to, control1: cp1, control2: cp2)
        }
        .stroke(Color.primary.opacity(0.001), lineWidth: 20)
        .onTapGesture {
            vm.selectedConnectionID = conn.id
            vm.selectedNodeID       = nil
        }
    }
}
