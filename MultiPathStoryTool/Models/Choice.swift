import Foundation
import SwiftData

@Model
final class Choice {
    @Attribute(.unique) var id: UUID
    /// Explicit sibling order — SwiftData to-many arrays don't guarantee order.
    var order: Int
    var parentNode: StoryNode?
    var targetNode: StoryNode?

    init(
        id: UUID = UUID(),
        order: Int,
        parentNode: StoryNode? = nil,
        targetNode: StoryNode? = nil
    ) {
        self.id = id
        self.order = order
        self.parentNode = parentNode
        self.targetNode = targetNode
    }

    /// One-indexed display label, e.g. "1", "2", "3". Cheap to compute, never stored.
    var label: String {
        "\(order + 1)"
    }
}
