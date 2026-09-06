import SwiftUI
import Foundation

let nodeWidth:    CGFloat = 180
let nodeHeight:   CGFloat = 64
let snapGridSize: CGFloat = 20
let curveStrength: CGFloat = 90

let pastelColors: [Color] = [
    Color(red: 1.0,  green: 0.78, blue: 0.80),
    Color(red: 0.80, green: 0.95, blue: 0.80),
    Color(red: 0.78, green: 0.84, blue: 1.0),
    Color(red: 1.0,  green: 0.97, blue: 0.76),
    Color(red: 0.95, green: 0.80, blue: 0.97),
    Color(red: 0.80, green: 0.96, blue: 0.98),
    Color(red: 1.0,  green: 0.89, blue: 0.76),
    Color(red: 0.88, green: 0.76, blue: 1.0),
]

struct StoryNode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var dialogue: String
    var position: CGPoint
    var width:    CGFloat
    var height:   CGFloat

    var shortID: String { String(id.uuidString.prefix(8)).uppercased() }

    // Explicit CodingKeys so the custom init(from:) can reference .width / .height
    // and encode(to:) is still auto-synthesised for all keys.
    enum CodingKeys: String, CodingKey {
        case id, name, dialogue, position, width, height
    }

    init(id: UUID = UUID(), name: String = "New Entry", dialogue: String = "",
         position: CGPoint = .zero,
         width: CGFloat = nodeWidth, height: CGFloat = nodeHeight) {
        self.id = id; self.name = name; self.dialogue = dialogue
        self.position = position; self.width = width; self.height = height
    }

    // Custom decoder: width/height default to nodeWidth/nodeHeight for old saves
    // that were written before per-node sizing was introduced.
    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,    forKey: .id)
        name     = try c.decode(String.self,  forKey: .name)
        dialogue = try c.decode(String.self,  forKey: .dialogue)
        position = try c.decode(CGPoint.self, forKey: .position)
        width    = try c.decodeIfPresent(CGFloat.self, forKey: .width)  ?? nodeWidth
        height   = try c.decodeIfPresent(CGFloat.self, forKey: .height) ?? nodeHeight
    }

    var bottomCenter: CGPoint { CGPoint(x: position.x + width  / 2, y: position.y + height) }
    var topCenter:    CGPoint { CGPoint(x: position.x + width  / 2, y: position.y) }
    var rect:         CGRect  { CGRect(x: position.x, y: position.y, width: width, height: height) }
}

struct StoryDocument: Codable {
    var nodes: [StoryNode]
    var connections: [NodeConnection]
    var groups: [StoryGroup] = []
    var version: Int = 1
}

struct StoryGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rect: CGRect
    var colorIndex: Int
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, rect, colorIndex, isPinned
    }

    init(id: UUID = UUID(), name: String = "Group", rect: CGRect,
         colorIndex: Int = 0, isPinned: Bool = false) {
        self.id = id; self.name = name; self.rect = rect
        self.colorIndex = colorIndex; self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self,   forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        rect       = try c.decode(CGRect.self, forKey: .rect)
        colorIndex = try c.decode(Int.self,    forKey: .colorIndex)
        isPinned   = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

struct NodeConnection: Identifiable, Codable, Equatable {
    let id: UUID
    var fromNodeID: UUID
    var toNodeID: UUID
    var isOrphaned: Bool
    var colorIndex: Int
    var orphanedFromPos: CGPoint?
    var orphanedToPos: CGPoint?

    init(id: UUID = UUID(), fromNodeID: UUID, toNodeID: UUID, colorIndex: Int = 0) {
        self.id = id
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.isOrphaned = false
        self.colorIndex = colorIndex
    }
}
