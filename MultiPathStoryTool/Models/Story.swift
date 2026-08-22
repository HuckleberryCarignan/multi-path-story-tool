import Foundation
import SwiftData

@Model
final class Story {
    var title: String
    var rootNodeID: UUID?
    var startingNumber: Int
    var canvasOffsetX: Double
    var canvasOffsetY: Double
    var canvasScale: Double

    @Relationship(deleteRule: .cascade)
    var nodes: [StoryNode] = []

    init(
        title: String = "Untitled Story",
        rootNodeID: UUID? = nil,
        startingNumber: Int = 1,
        canvasOffsetX: Double = 0,
        canvasOffsetY: Double = 0,
        canvasScale: Double = 1.0
    ) {
        self.title = title
        self.rootNodeID = rootNodeID
        self.startingNumber = startingNumber
        self.canvasOffsetX = canvasOffsetX
        self.canvasOffsetY = canvasOffsetY
        self.canvasScale = canvasScale
    }
}

extension Story {
    /// Recomputes `displayNumber` for every node via a depth-first, pre-order
    /// traversal starting at the root. This is the single source of truth for
    /// numbering and must only be called from `StoryMutator` after structural
    /// tree edits — never on every keystroke or drag.
    func renumberTree() {
        guard let rootID = rootNodeID,
              let root = nodes.first(where: { $0.id == rootID }) else { return }
        var next = startingNumber
        func visit(_ node: StoryNode) {
            node.displayNumber = next
            next += 1
            for choice in node.choices.sorted(by: { $0.order < $1.order }) {
                if let child = choice.targetNode {
                    visit(child)
                }
            }
        }
        visit(root)
    }
}
