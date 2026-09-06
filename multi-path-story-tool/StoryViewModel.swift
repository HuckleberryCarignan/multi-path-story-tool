import SwiftUI

@Observable
class StoryViewModel {
    var nodes: [StoryNode] = [] {
        didSet { if !suppressChangeTracking { hasUnsavedChanges = true } }
    }
    var connections: [NodeConnection] = [] {
        didSet { if !suppressChangeTracking { hasUnsavedChanges = true } }
    }
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
    var isDialogueExpanded: Bool = false
    var groups: [StoryGroup] = [] {
        didSet { if !suppressChangeTracking { hasUnsavedChanges = true } }
    }
    var selectedGroupID: UUID? = nil
    var isDrawingGroup:  Bool  = false
    private var nextColorIndex      = 0
    private var nextGroupColorIndex = 0

    // MARK: - Document state

    var currentFileURL: URL?    = nil
    var hasUnsavedChanges: Bool = false
    var startNodeID: UUID?      = nil
    private var suppressChangeTracking = false

    // Weakly held so we don't create a retain cycle with the window's UndoManager.
    weak var undoManager: UndoManager?

    var documentTitle: String {
        currentFileURL.map { $0.deletingPathExtension().lastPathComponent } ?? "Untitled"
    }

    // MARK: - Undo / Redo

    private struct Snapshot {
        let nodes:       [StoryNode]
        let connections: [NodeConnection]
        let groups:      [StoryGroup]
        let startNodeID: UUID?
    }

    private func checkpoint() -> Snapshot {
        Snapshot(nodes: nodes, connections: connections,
                 groups: groups, startNodeID: startNodeID)
    }

    // Restore document state; clears selection so stale IDs don't linger.
    private func restore(_ s: Snapshot) {
        suppressChangeTracking = true
        defer { suppressChangeTracking = false }
        nodes       = s.nodes
        connections = s.connections
        groups      = s.groups
        startNodeID = s.startNodeID
        selectedNodeID       = nil
        selectedNodeIDs      = []
        selectedConnectionID = nil
        selectedGroupID      = nil
        connectingFromNodeID = nil
        hasUnsavedChanges    = true
    }

    // Register a reversible action. Calling this within an undo/redo handler
    // automatically registers the paired redo/undo, giving a full undo stack.
    private func registerUndo(action: String, from snapshot: Snapshot) {
        undoManager?.registerUndo(withTarget: self) { vm in
            let redo = vm.checkpoint()
            vm.restore(snapshot)
            vm.undoManager?.registerUndo(withTarget: vm) { vm2 in
                vm2.restore(redo)
                vm2.undoManager?.setActionName(action)
            }
            vm.undoManager?.setActionName(action)
        }
        undoManager?.setActionName(action)
    }

    // MARK: - File operations
    // All methods that show AppKit panels dispatch to the next run loop tick so
    // SwiftUI finishes its button-action pass before a modal run loop starts.

    func newDocument() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hasUnsavedChanges {
                self.confirmDiscardChanges { [weak self] in self?.resetDocument() }
            } else {
                self.resetDocument()
            }
        }
    }

    func saveDocument() {
        if let url = currentFileURL {
            writeToDisk(url: url)
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let panel = NSSavePanel()
            panel.title = "Save Story"
            panel.nameFieldStringValue = "\(self.documentTitle).mpst"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            self.currentFileURL = url
            self.writeToDisk(url: url)
        }
    }

    func exportAsText() {
        let toExport = nodes
        guard !toExport.isEmpty else { return }

        // Pin the designated beginning entry to position 1; shuffle the rest
        var pool = toExport
        var ordered: [StoryNode]
        if let startID = startNodeID,
           let startIdx = pool.firstIndex(where: { $0.id == startID }) {
            let startNode = pool.remove(at: startIdx)
            ordered = [startNode] + pool.shuffled()
        } else {
            ordered = pool.shuffled()
        }
        let shuffled = ordered

        // Map each shortID to its new sequential number (1-based)
        var idMap: [String: Int] = [:]
        for (i, node) in shuffled.enumerated() {
            idMap[node.shortID] = i + 1
        }

        // Build the exported text
        let bar = String(repeating: "━", count: 48)
        var lines: [String] = [
            "Multi-Path Story Export",
            "Document: \(documentTitle)",
            "Entries: \(shuffled.count)",
            "",
        ]
        for (i, node) in shuffled.enumerated() {
            lines += [
                bar,
                "Entry \(i + 1) — \(node.name)",
                bar,
                "",
            ]
            if node.dialogue.isEmpty {
                lines.append("(no dialogue)")
            } else {
                lines.append(replaceIDReferences(in: node.dialogue, using: idMap))
            }
            lines += ["", ""]
        }
        let text = lines.joined(separator: "\n")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let panel = NSSavePanel()
            panel.title = "Export as Text"
            panel.nameFieldStringValue = "\(self.documentTitle).txt"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // Replaces {SHORTID/Title} patterns in dialogue with "→ Entry N" using the provided map.
    // References to IDs not in the map (outside the export set) are left unchanged.
    private func replaceIDReferences(in text: String, using map: [String: Int]) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{([A-F0-9]{8})/([^}]+)\}"#) else { return text }
        var replacements: [(range: Range<String.Index>, replacement: String)] = []
        regex.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            guard let match,
                  let fullRange  = Range(match.range, in: text),
                  let idRange    = Range(match.range(at: 1), in: text) else { return }
            let shortID = String(text[idRange])
            if let number = map[shortID] {
                replacements.append((fullRange, "→ Entry \(number)"))
            }
        }
        // Apply in reverse so earlier indices stay valid as the string mutates
        var result = text
        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    func openDocument() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hasUnsavedChanges {
                self.confirmDiscardChanges { [weak self] in self?.presentOpenPanel() }
            } else {
                self.presentOpenPanel()
            }
        }
    }

    // MARK: - Private helpers

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Story"
        panel.message = "Select a .mpst file"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFromDisk(url: url)
    }

    // Calls onProceed if the user saves successfully or explicitly discards.
    // Nothing happens (closure not called) if the user cancels.
    private func confirmDiscardChanges(onProceed: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save changes to \"\(documentTitle)\"?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:   // Save first, then proceed
            if let url = currentFileURL {
                if writeToDisk(url: url) { onProceed() }
            } else {
                let panel = NSSavePanel()
                panel.title = "Save Story"
                panel.nameFieldStringValue = "\(documentTitle).mpst"
                guard panel.runModal() == .OK, let url = panel.url else { return }
                currentFileURL = url
                if writeToDisk(url: url) { onProceed() }
            }
        case .alertSecondButtonReturn:  // Discard and proceed
            onProceed()
        default:                        // Cancel — do nothing
            return
        }
    }

    @discardableResult
    private func writeToDisk(url: URL) -> Bool {
        let doc = StoryDocument(nodes: nodes, connections: connections, groups: groups)
        guard let data = try? JSONEncoder().encode(doc) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            hasUnsavedChanges = false
            return true
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could not save file"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    private func loadFromDisk(url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could not read file"
            alert.informativeText = url.lastPathComponent
            alert.runModal()
            return
        }
        guard let doc = try? JSONDecoder().decode(StoryDocument.self, from: data) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "File is not a valid story"
            alert.informativeText = url.lastPathComponent
            alert.runModal()
            return
        }
        suppressChangeTracking = true
        defer { suppressChangeTracking = false }
        nodes = doc.nodes
        connections = doc.connections
        groups = doc.groups
        selectedNodeID = nil
        selectedNodeIDs = []
        selectedConnectionID = nil
        connectingFromNodeID = nil
        currentFileURL = url
        hasUnsavedChanges = false
        undoManager?.removeAllActions()
    }

    private func resetDocument() {
        suppressChangeTracking = true
        defer { suppressChangeTracking = false }
        nodes = []
        connections = []
        groups = []
        selectedGroupID = nil
        selectedNodeID = nil
        selectedNodeIDs = []
        selectedConnectionID = nil
        connectingFromNodeID = nil
        startNodeID = nil
        currentFileURL = nil
        hasUnsavedChanges = false
        undoManager?.removeAllActions()
    }

    // MARK: - Canvas node management

    var selectedNode: StoryNode? {
        guard let id = selectedNodeID else { return nil }
        return nodes.first { $0.id == id }
    }

    func addNode(at position: CGPoint) {
        let before  = checkpoint()
        let snapped = snap(position)
        let placed  = freePosition(near: snapped, excluding: nil)
        let node    = StoryNode(position: placed)
        nodes.append(node)
        selectedNodeID  = node.id
        selectedNodeIDs = [node.id]
        registerUndo(action: "Add Entry", from: before)
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
        guard nodes.contains(where: { $0.id == id }) else { return }
        let before = checkpoint()
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
        if selectedNodeID      == id { selectedNodeID      = selectedNodeIDs.first }
        if connectingFromNodeID == id { connectingFromNodeID = nil }
        if startNodeID          == id { startNodeID          = nil }
        registerUndo(action: "Delete Entry", from: before)
    }

    func addConnection(from fromID: UUID, to toID: UUID) {
        guard fromID != toID else { return }
        guard !connections.contains(where: {
            $0.fromNodeID == fromID && $0.toNodeID == toID && !$0.isOrphaned
        }) else { return }
        let before = checkpoint()
        connections.append(NodeConnection(fromNodeID: fromID, toNodeID: toID,
                                          colorIndex: nextColorIndex % pastelColors.count))
        nextColorIndex += 1
        registerUndo(action: "Add Connection", from: before)
    }

    func removeConnection(_ id: UUID) {
        guard connections.contains(where: { $0.id == id }) else { return }
        let before = checkpoint()
        connections.removeAll { $0.id == id }
        if selectedConnectionID == id { selectedConnectionID = nil }
        registerUndo(action: "Remove Connection", from: before)
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
        let before = checkpoint()
        nodes[idx].position = snap(nodes[idx].position)
        registerUndo(action: "Snap to Grid", from: before)
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
        let hasOverlap = proposed.contains { (id, pos) in
            let rect = CGRect(x: pos.x, y: pos.y, width: nodeWidth, height: nodeHeight)
            return nodes.contains { node in !ids.contains(node.id) && node.rect.intersects(rect) }
        }
        guard !hasOverlap else { return }
        let before = checkpoint()
        for (id, pos) in proposed {
            if let idx = nodes.firstIndex(where: { $0.id == id }) {
                nodes[idx].position = pos
            }
        }
        registerUndo(action: "Move Entries", from: before)
    }

    func finishDrag(_ id: UUID, by delta: CGSize, from originalPosition: CGPoint) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        let proposed = snap(CGPoint(
            x: originalPosition.x + delta.width,
            y: originalPosition.y + delta.height
        ))
        guard !isOverlapping(id: id, at: proposed) else { return }
        let before = checkpoint()
        nodes[idx].position = proposed
        registerUndo(action: "Move Entry", from: before)
    }

    func updateNodeName(_ id: UUID, _ name: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        guard nodes[idx].name != name else { return }
        let before = checkpoint()
        nodes[idx].name = name
        registerUndo(action: "Rename Entry", from: before)
    }

    // MARK: - Group box management

    func addGroup(worldRect: CGRect) {
        let before = checkpoint()
        let g = StoryGroup(rect: worldRect, colorIndex: nextGroupColorIndex % pastelColors.count)
        nextGroupColorIndex += 1
        groups.append(g)
        selectedGroupID      = g.id
        selectedNodeID       = nil
        selectedNodeIDs      = []
        selectedConnectionID = nil
        isDrawingGroup       = false
        registerUndo(action: "Add Group", from: before)
    }

    func toggleGroupPin(_ id: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        let before = checkpoint()
        groups[idx].isPinned.toggle()
        let action = groups[idx].isPinned ? "Lock Group Contents" : "Unlock Group Contents"
        registerUndo(action: action, from: before)
    }

    func moveGroup(_ id: UUID, by delta: CGSize) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        let before = checkpoint()
        groups[idx].rect.origin.x += delta.width
        groups[idx].rect.origin.y += delta.height
        registerUndo(action: "Move Group", from: before)
    }

    // Moves the group and the specified node IDs together (used when the group is pinned).
    func moveGroupWithContents(_ id: UUID, by delta: CGSize, nodesInside: [UUID]) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        let before = checkpoint()
        groups[idx].rect.origin.x += delta.width
        groups[idx].rect.origin.y += delta.height
        for nodeID in nodesInside {
            guard let nIdx = nodes.firstIndex(where: { $0.id == nodeID }) else { continue }
            nodes[nIdx].position.x += delta.width
            nodes[nIdx].position.y += delta.height
        }
        registerUndo(action: "Move Group", from: before)
    }

    func resizeGroup(_ id: UUID, by delta: CGSize) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        let before = checkpoint()
        let minW: CGFloat = 120, minH: CGFloat = 80
        groups[idx].rect.size.width  = max(minW, groups[idx].rect.size.width  + delta.width)
        groups[idx].rect.size.height = max(minH, groups[idx].rect.size.height + delta.height)
        registerUndo(action: "Resize Group", from: before)
    }

    func deleteGroup(_ id: UUID) {
        guard groups.contains(where: { $0.id == id }) else { return }
        let before = checkpoint()
        groups.removeAll { $0.id == id }
        if selectedGroupID == id { selectedGroupID = nil }
        registerUndo(action: "Delete Group", from: before)
    }

    func renameGroup(_ id: UUID, _ name: String) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        let before = checkpoint()
        groups[idx].name = name.isEmpty ? "Group" : name
        registerUndo(action: "Rename Group", from: before)
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
