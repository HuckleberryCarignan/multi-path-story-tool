import SwiftUI
import Foundation

let nodeWidth: CGFloat = 180
let nodeHeight: CGFloat = 64
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

    var shortID: String { String(id.uuidString.prefix(8)).uppercased() }

    init(id: UUID = UUID(), name: String = "New Entry", dialogue: String = "", position: CGPoint = .zero) {
        self.id = id
        self.name = name
        self.dialogue = dialogue
        self.position = position
    }

    var bottomCenter: CGPoint { CGPoint(x: position.x + nodeWidth / 2, y: position.y + nodeHeight) }
    var topCenter: CGPoint    { CGPoint(x: position.x + nodeWidth / 2, y: position.y) }
    var rect: CGRect          { CGRect(x: position.x, y: position.y, width: nodeWidth, height: nodeHeight) }
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
