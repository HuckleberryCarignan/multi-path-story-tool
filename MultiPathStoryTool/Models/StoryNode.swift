import CoreGraphics
import Foundation
import SwiftData

@Model
final class StoryNode {
    @Attribute(.unique) var id: UUID
    var displayNumber: Int
    var passageText: String
    var positionX: Double
    var positionY: Double

    /// Outgoing choices authored on this node's passage text.
    @Relationship(deleteRule: .cascade, inverse: \Choice.parentNode)
    var choices: [Choice] = []

    /// The single choice (from some other node) that links to this node, if any.
    /// `nil` for the root node.
    @Relationship(inverse: \Choice.targetNode)
    var incomingChoice: Choice?

    init(
        id: UUID = UUID(),
        displayNumber: Int = 0,
        passageText: String = "",
        positionX: Double = 0,
        positionY: Double = 0
    ) {
        self.id = id
        self.displayNumber = displayNumber
        self.passageText = passageText
        self.positionX = positionX
        self.positionY = positionY
    }

    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }
}
