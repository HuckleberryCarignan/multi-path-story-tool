import SwiftUI

@Observable
class StoryViewModel {
    var nodes: [StoryNode] = []
    var connections: [NodeConnection] = []
    var selectedNodeID: UUID? = nil
    var selectedNodeIDs: Set<UUID> = []
    var selectedConnectionID: UUID? = nil
    var connectingFromNodeID: UUID? = nil
    var snapEnabled: Bool = true
    var gridSize: CGFloat = snapGridSize
    var showIdentifier: Bool = true
    var showCanvasIdentifier: Bool = true
    var addNodeOnCommandClick: Bool = true
    var rightJustifiedOnCanvas: Bool = true
    var showZoomOut: Bool = true
    private var nextColorIndex = 0

    var selectedNode: StoryNode? {
        guard let id = selectedNodeID else { return nil }
        return nodes.first { $0.id == id }
    }

    func addNode(at position: CGPoint) {
        let snapped = snap(position)
        let placed  = freePosition(near: snapped, excluding: nil)
        let node    = StoryNode(position: placed)
        nodes.append(node)
        selectedNodeID  = node.id
        selectedNodeIDs = [node.id]
    }

    func toggleSelection(_ id: UUID) {
        if selectedNodeIDs.contains(id) {
            selectedNodeIDs.remove(id)
            if selectedNodeID == id { selectedNodeID = selectedNodeIDs.first }
        } else {
            selectedNodeIDs.insert(id)
            selectedNodeID = id
        }
        selectedConnectionID = nil
    }

    func deleteNode(_ id: UUID) {
        guard let node = nodes.first(where: { $0.id == id }) else { return }
        for i in connections.indices {
            if connections[i].fromNodeID == id {
                connections[i].isOrphaned = true
                connections[i].orphanedFromPos = node.bottomCenter
            }
            if connections[i].toNodeID == id {
                connections[i].isOrphaned = true
                connections[i].orphanedToPos = node.topCenter
            }
        }
        nodes.removeAll { $0.id == id }
        selectedNodeIDs.remove(id)
        if selectedNodeID == id { selectedNodeID = selectedNodeIDs.first }
        if connectingFromNodeID == id { connectingFromNodeID = nil }
    }

    func addConnection(from fromID: UUID, to toID: UUID) {
        guard fromID != toID else { return }
        guard !connections.contains(where: {
            $0.fromNodeID == fromID && $0.toNodeID == toID && !$0.isOrphaned
        }) else { return }
        connections.append(NodeConnection(fromNodeID: fromID, toNodeID: toID, colorIndex: nextColorIndex % pastelColors.count))
        nextColorIndex += 1
    }

    func removeConnection(_ id: UUID) {
        connections.removeAll { $0.id == id }
        if selectedConnectionID == id { selectedConnectionID = nil }
    }

    func moveNode(_ id: UUID, by delta: CGSize) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].position = CGPoint(
            x: nodes[idx].position.x + delta.width,
            y: nodes[idx].position.y + delta.height
        )
    }

    func snapNodeToGrid(_ id: UUID) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].position = snap(nodes[idx].position)
    }

    func finishGroupDrag(ids: Set<UUID>, by delta: CGSize, from origins: [UUID: CGPoint]) {
        var proposed: [UUID: CGPoint] = [:]
        for id in ids {
            guard let origin = origins[id] else { continue }
            proposed[id] = snap(CGPoint(
                x: origin.x + delta.width,
                y: origin.y + delta.height
            ))
        }
        // Revert entire group if any member would overlap a node outside the group
        let hasOverlap = proposed.contains { (id, pos) in
            let rect = CGRect(x: pos.x, y: pos.y, width: nodeWidth, height: nodeHeight)
            return nodes.contains { node in !ids.contains(node.id) && node.rect.intersects(rect) }
        }
        guard !hasOverlap else { return }
        for (id, pos) in proposed {
            if let idx = nodes.firstIndex(where: { $0.id == id }) {
                nodes[idx].position = pos
            }
        }
    }

    // Commits a drag: snaps the proposed position and reverts to originalPosition if it overlaps another node.
    func finishDrag(_ id: UUID, by delta: CGSize, from originalPosition: CGPoint) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        let proposed = snap(CGPoint(
            x: originalPosition.x + delta.width,
            y: originalPosition.y + delta.height
        ))
        nodes[idx].position = isOverlapping(id: id, at: proposed) ? originalPosition : proposed
    }

    func updateNodeName(_ id: UUID, _ name: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].name = name
    }

    func outgoingConnections(for nodeID: UUID) -> [(connection: NodeConnection, target: StoryNode?)] {
        connections
            .filter { $0.fromNodeID == nodeID && !$0.isOrphaned }
            .map { conn in (connection: conn, target: nodes.first { $0.id == conn.toNodeID }) }
    }

    private func snap(_ p: CGPoint) -> CGPoint {
        guard snapEnabled else { return p }
        return CGPoint(
            x: round(p.x / gridSize) * gridSize,
            y: round(p.y / gridSize) * gridSize
        )
    }

    private func isOverlapping(id: UUID?, at position: CGPoint) -> Bool {
        let rect = CGRect(x: position.x, y: position.y, width: nodeWidth, height: nodeHeight)
        return nodes.contains { node in node.id != id && node.rect.intersects(rect) }
    }

    // Spirals outward from `origin` to find the nearest grid-snapped position that
    // doesn't overlap any existing node (other than the one identified by `excluding`).
    private func freePosition(near origin: CGPoint, excluding id: UUID?) -> CGPoint {
        if !isOverlapping(id: id, at: origin) { return origin }
        let step: CGFloat = snapEnabled ? gridSize : 10
        for ring in 1...50 {
            let dist = step * CGFloat(ring)
            for deg in stride(from: CGFloat(0), to: 360, by: 45) {
                let rad = deg * .pi / 180
                let candidate = snap(CGPoint(
                    x: origin.x + dist * cos(rad),
                    y: origin.y + dist * sin(rad)
                ))
                if !isOverlapping(id: id, at: candidate) { return candidate }
            }
        }
        return origin
    }
}
