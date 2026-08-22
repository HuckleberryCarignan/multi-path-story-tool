import Foundation
import SwiftData

/// Centralized surface for all structural edits to a story's node tree
/// (adding branches, deleting subtrees). Every mutation here concludes by
/// calling `story.renumberTree()`, guaranteeing `StoryNode.displayNumber`
/// stays consistent with a DFS pre-order traversal of the tree.
enum StoryMutator {
    private static let horizontalSpacing: Double = 320
    private static let verticalSpacing: Double = 180

    /// Appends a numbered choice line to `parentNode`'s passage text, creates
    /// a new linked child `StoryNode`, positions it near the parent (avoiding
    /// overlap with existing siblings), and renumbers the tree.
    @discardableResult
    static func addChoiceAndChild(to parentNode: StoryNode, in story: Story, context: ModelContext) -> StoryNode {
        let order = parentNode.choices.count

        let child = StoryNode()
        child.positionX = parentNode.positionX + horizontalSpacing
        child.positionY = parentNode.positionY + Double(order) * verticalSpacing

        let choice = Choice(order: order)
        choice.parentNode = parentNode
        choice.targetNode = child

        context.insert(child)
        context.insert(choice)

        story.nodes.append(child)

        let choiceNumber = order + 1
        if !parentNode.passageText.isEmpty && !parentNode.passageText.hasSuffix("\n") {
            parentNode.passageText += "\n"
        }
        parentNode.passageText += "\(choiceNumber). "

        story.renumberTree()
        return child
    }

    /// Recursively deletes `node` and its entire subtree, removes the
    /// incoming choice that linked it to its parent, compacts the parent's
    /// remaining sibling `order` values, and renumbers the tree. The root
    /// node cannot be deleted.
    static func deleteNode(_ node: StoryNode, in story: Story, context: ModelContext) {
        guard node.id != story.rootNodeID else { return }

        var subtree: [StoryNode] = []
        func collect(_ current: StoryNode) {
            subtree.append(current)
            for choice in current.choices {
                if let child = choice.targetNode {
                    collect(child)
                }
            }
        }
        collect(node)

        if let incoming = node.incomingChoice, let parent = incoming.parentNode {
            let remainingSiblings = parent.choices
                .filter { $0.id != incoming.id }
                .sorted { $0.order < $1.order }
            for (index, sibling) in remainingSiblings.enumerated() {
                sibling.order = index
            }
            // `context.delete` does not synchronously purge the deleted
            // object from an already-loaded to-many relationship array, so
            // remove it explicitly to keep `parent.choices` accurate
            // in-memory without requiring a save.
            parent.choices.removeAll { $0.id == incoming.id }
            context.delete(incoming)
        }

        for descendant in subtree {
            story.nodes.removeAll { $0.id == descendant.id }
            context.delete(descendant)
        }

        story.renumberTree()
    }
}
