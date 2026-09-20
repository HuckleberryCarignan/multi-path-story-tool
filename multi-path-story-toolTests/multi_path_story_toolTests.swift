//
//  multi_path_story_toolTests.swift
//  multi-path-story-toolTests
//
//  Created by Christopher Carignan on 8/22/26.
//

import Testing
import Foundation
import CoreGraphics
@testable import multi_path_story_tool

// MARK: - StoryNode

@MainActor
@Suite("StoryNode")
struct StoryNodeTests {

    @Test func defaultInitValues() {
        let node = StoryNode()
        #expect(node.name == "New Entry")
        #expect(node.dialogue == "")
        #expect(node.position == .zero)
        #expect(node.width == nodeWidth)
        #expect(node.height == nodeHeight)
    }

    @Test func shortIDIsFirstEightUppercasedCharacters() {
        let id = UUID()
        let node = StoryNode(id: id)
        let expected = String(id.uuidString.prefix(8)).uppercased()
        #expect(node.shortID == expected)
        #expect(node.shortID.count == 8)
    }

    @Test func geometryComputations() {
        let node = StoryNode(position: CGPoint(x: 10, y: 20), width: 100, height: 50)
        #expect(node.topCenter == CGPoint(x: 60, y: 20))
        #expect(node.bottomCenter == CGPoint(x: 60, y: 70))
        #expect(node.rect == CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    @Test func codableRoundTrip() throws {
        let original = StoryNode(name: "Hello", dialogue: "World",
                                  position: CGPoint(x: 5, y: 6), width: 200, height: 80)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StoryNode.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodingMissingWidthHeightUsesDefaults() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Old","dialogue":"","position":[1,2]}
        """
        let decoded = try JSONDecoder().decode(StoryNode.self, from: Data(json.utf8))
        #expect(decoded.width == nodeWidth)
        #expect(decoded.height == nodeHeight)
        #expect(decoded.name == "Old")
    }
}

// MARK: - StoryGroup

@MainActor
@Suite("StoryGroup")
struct StoryGroupTests {

    @Test func defaultInitValues() {
        let group = StoryGroup(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(group.name == "Group")
        #expect(group.colorIndex == 0)
        #expect(group.isPinned == false)
    }

    @Test func codableRoundTrip() throws {
        let original = StoryGroup(name: "Act 1", rect: CGRect(x: 1, y: 2, width: 3, height: 4),
                                   colorIndex: 2, isPinned: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StoryGroup.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodingMissingIsPinnedDefaultsFalse() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Old Group","rect":[[0,0],[1,1]],"colorIndex":0}
        """
        let decoded = try JSONDecoder().decode(StoryGroup.self, from: Data(json.utf8))
        #expect(decoded.isPinned == false)
    }
}

// MARK: - NodeConnection

@MainActor
@Suite("NodeConnection")
struct NodeConnectionTests {

    @Test func defaultInitValues() {
        let from = UUID(), to = UUID()
        let conn = NodeConnection(fromNodeID: from, toNodeID: to, colorIndex: 3)
        #expect(conn.fromNodeID == from)
        #expect(conn.toNodeID == to)
        #expect(conn.colorIndex == 3)
        #expect(conn.isOrphaned == false)
        #expect(conn.entryPortOverride == nil)
        #expect(conn.exitPortOverride == nil)
    }
}

// MARK: - StoryViewModel: Node management

@MainActor
@Suite("StoryViewModel node management")
struct StoryViewModelNodeTests {

    @Test func addNodeAppendsAndSelectsIt() {
        let vm = StoryViewModel()
        vm.addNode(at: CGPoint(x: 100, y: 100))
        #expect(vm.nodes.count == 1)
        #expect(vm.selectedNodeID == vm.nodes[0].id)
        #expect(vm.selectedNodeIDs == [vm.nodes[0].id])
    }

    @Test func addNodeAvoidsOverlappingExistingNode() {
        let vm = StoryViewModel()
        vm.addNode(at: CGPoint(x: 0, y: 0))
        vm.addNode(at: CGPoint(x: 0, y: 0))
        #expect(vm.nodes.count == 2)
        #expect(vm.nodes[0].position != vm.nodes[1].position)
        #expect(!vm.nodes[0].rect.intersects(vm.nodes[1].rect))
    }

    @Test func deleteNodeOrphansConnectedEdgesInBothDirections() {
        let vm = StoryViewModel()
        let a = StoryNode(position: CGPoint(x: 0, y: 0))
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        vm.nodes = [a, b]
        vm.addConnection(from: a.id, to: b.id)
        vm.addConnection(from: b.id, to: a.id)
        vm.startNodeID = a.id
        vm.connectingFromNodeID = a.id

        vm.deleteNode(a.id)

        #expect(vm.nodes.count == 1)
        #expect(vm.connections.allSatisfy { $0.isOrphaned })
        let aToB = vm.connections.first { $0.toNodeID == b.id }!
        #expect(aToB.orphanedFromPos == a.bottomCenter)
        let bToA = vm.connections.first { $0.fromNodeID == b.id }!
        #expect(bToA.orphanedToPos == a.topCenter)
        #expect(vm.startNodeID == nil)
        #expect(vm.connectingFromNodeID == nil)
    }

    @Test func deleteNonexistentNodeIsNoOp() {
        let vm = StoryViewModel()
        vm.nodes = [StoryNode(position: .zero)]
        vm.deleteNode(UUID())
        #expect(vm.nodes.count == 1)
    }

    @Test func toggleSelectionAddsThenRemoves() {
        let vm = StoryViewModel()
        let id = UUID()
        vm.selectedConnectionID = UUID()

        vm.toggleSelection(id)
        #expect(vm.selectedNodeIDs.contains(id))
        #expect(vm.selectedNodeID == id)
        #expect(vm.selectedConnectionID == nil)

        vm.toggleSelection(id)
        #expect(!vm.selectedNodeIDs.contains(id))
        #expect(vm.selectedNodeID == nil)
    }

    @Test func moveNodeAddsDeltaWithoutSnapping() {
        let vm = StoryViewModel()
        let node = StoryNode(position: CGPoint(x: 10, y: 10))
        vm.nodes = [node]
        vm.moveNode(node.id, by: CGSize(width: 5, height: -3))
        #expect(vm.nodes[0].position == CGPoint(x: 15, y: 7))
    }

    @Test func snapNodeToGridRoundsToNearestGridPoint() {
        let vm = StoryViewModel()
        let node = StoryNode(position: CGPoint(x: 15, y: 15))
        vm.nodes = [node]
        vm.snapNodeToGrid(node.id)
        #expect(vm.nodes[0].position == CGPoint(x: 20, y: 20))
    }

    @Test func finishDragAppliesWhenDestinationIsFree() {
        let vm = StoryViewModel()
        let a = StoryNode(id: UUID(), position: .zero)
        let b = StoryNode(id: UUID(), position: CGPoint(x: 500, y: 500))
        vm.nodes = [a, b]
        vm.finishDrag(a.id, by: CGSize(width: 10, height: 10), from: .zero)
        #expect(vm.nodes.first { $0.id == a.id }!.position == CGPoint(x: 20, y: 20))
    }

    @Test func finishDragIsBlockedByOverlap() {
        let vm = StoryViewModel()
        let a = StoryNode(id: UUID(), position: .zero)
        let b = StoryNode(id: UUID(), position: CGPoint(x: 200, y: 0))
        vm.nodes = [a, b]
        vm.finishDrag(a.id, by: CGSize(width: 50, height: 0), from: .zero)
        #expect(vm.nodes.first { $0.id == a.id }!.position == .zero)
    }

    @Test func finishGroupDragMovesAllSelectedNodesTogether() {
        let vm = StoryViewModel()
        let a = StoryNode(id: UUID(), position: CGPoint(x: 0, y: 0))
        let b = StoryNode(id: UUID(), position: CGPoint(x: 300, y: 0))
        let c = StoryNode(id: UUID(), position: CGPoint(x: 900, y: 900))
        vm.nodes = [a, b, c]
        let origins: [UUID: CGPoint] = [a.id: a.position, b.id: b.position]

        vm.finishGroupDrag(ids: [a.id, b.id], by: CGSize(width: 10, height: 10), from: origins)

        #expect(vm.nodes.first { $0.id == a.id }!.position == CGPoint(x: 20, y: 20))
        #expect(vm.nodes.first { $0.id == b.id }!.position == CGPoint(x: 320, y: 20))
        #expect(vm.nodes.first { $0.id == c.id }!.position == CGPoint(x: 900, y: 900))
    }

    @Test func finishGroupDragIsBlockedIfAnyMemberWouldOverlapANonMember() {
        let vm = StoryViewModel()
        let a = StoryNode(id: UUID(), position: CGPoint(x: 0, y: 0))
        let b = StoryNode(id: UUID(), position: CGPoint(x: 300, y: 0))
        let d = StoryNode(id: UUID(), position: CGPoint(x: 400, y: 0))
        vm.nodes = [a, b, d]
        let origins: [UUID: CGPoint] = [a.id: a.position, b.id: b.position]

        vm.finishGroupDrag(ids: [a.id, b.id], by: CGSize(width: 110, height: 0), from: origins)

        #expect(vm.nodes.first { $0.id == a.id }!.position == .zero)
        #expect(vm.nodes.first { $0.id == b.id }!.position == CGPoint(x: 300, y: 0))
    }

    @Test func updateNodeNameChangesAndIgnoresUnchangedValue() {
        let vm = StoryViewModel()
        let node = StoryNode(name: "Original", position: .zero)
        vm.nodes = [node]

        vm.updateNodeName(node.id, "Original")
        #expect(vm.nodes[0].name == "Original")

        vm.updateNodeName(node.id, "Renamed")
        #expect(vm.nodes[0].name == "Renamed")
    }
}

// MARK: - StoryViewModel: Connections

@MainActor
@Suite("StoryViewModel connections")
struct StoryViewModelConnectionTests {

    @Test func addConnectionAppendsAndIncrementsColorIndex() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        vm.nodes = [a, b]

        vm.addConnection(from: a.id, to: b.id)
        vm.addConnection(from: b.id, to: a.id)

        #expect(vm.connections.count == 2)
        #expect(vm.connections[0].colorIndex == 0)
        #expect(vm.connections[1].colorIndex == 1)
    }

    @Test func addConnectionPreventsSelfLoop() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        vm.nodes = [a]
        vm.addConnection(from: a.id, to: a.id)
        #expect(vm.connections.isEmpty)
    }

    @Test func addConnectionPreventsExactDuplicate() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        vm.nodes = [a, b]
        vm.addConnection(from: a.id, to: b.id)
        vm.addConnection(from: a.id, to: b.id)
        #expect(vm.connections.count == 1)
    }

    @Test func removeConnectionClearsSelection() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        vm.nodes = [a, b]
        vm.addConnection(from: a.id, to: b.id)
        let connID = vm.connections[0].id
        vm.selectedConnectionID = connID

        vm.removeConnection(connID)

        #expect(vm.connections.isEmpty)
        #expect(vm.selectedConnectionID == nil)
    }

    @Test func outgoingConnectionsExcludesOrphanedAndOtherSources() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        let c = StoryNode(position: CGPoint(x: 600, y: 0))
        let d = StoryNode(position: CGPoint(x: 900, y: 0))
        vm.nodes = [a, b, c, d]
        vm.addConnection(from: a.id, to: b.id)
        vm.addConnection(from: a.id, to: c.id)
        vm.addConnection(from: a.id, to: d.id)
        vm.addConnection(from: b.id, to: a.id)

        vm.deleteNode(d.id) // orphans the a -> d connection

        let outgoing = vm.outgoingConnections(for: a.id)
        #expect(outgoing.count == 2)
        #expect(outgoing.allSatisfy { $0.target != nil })
        #expect(Set(outgoing.map { $0.target!.id }) == Set([b.id, c.id]))
    }

    @Test func setConnectionPortsUpdateOverrides() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        vm.nodes = [a, b]
        vm.addConnection(from: a.id, to: b.id)
        let connID = vm.connections[0].id

        vm.setConnectionEntryPort(connID, port: "left")
        vm.setConnectionExitPort(connID, port: "right")
        #expect(vm.connections[0].entryPortOverride == "left")
        #expect(vm.connections[0].exitPortOverride == "right")

        vm.setConnectionEntryPort(connID, port: nil)
        #expect(vm.connections[0].entryPortOverride == nil)
    }
}

// MARK: - StoryViewModel: Multi-select, copy & paste

@MainActor
@Suite("StoryViewModel multi-select and clipboard")
struct StoryViewModelClipboardTests {

    @Test func deleteSelectedNodesOrphansTheirConnections() {
        let vm = StoryViewModel()
        let a = StoryNode(position: .zero)
        let b = StoryNode(position: CGPoint(x: 300, y: 0))
        let c = StoryNode(position: CGPoint(x: 600, y: 0))
        vm.nodes = [a, b, c]
        vm.addConnection(from: a.id, to: b.id)
        vm.addConnection(from: b.id, to: c.id)
        vm.selectedNodeIDs = [a.id, b.id]
        vm.selectedNodeID = a.id

        vm.deleteSelectedNodes()

        #expect(vm.nodes.map(\.id) == [c.id])
        #expect(vm.connections.allSatisfy { $0.isOrphaned })
        #expect(vm.selectedNodeIDs.isEmpty)
        #expect(vm.selectedNodeID == nil)
    }

    @Test func copyThenPasteOffsetsNodesAndRemapsConnections() {
        let vm = StoryViewModel()
        let a = StoryNode(name: "A", dialogue: "hello", position: CGPoint(x: 0, y: 0))
        let b = StoryNode(name: "B", dialogue: "world", position: CGPoint(x: 300, y: 0))
        vm.nodes = [a, b]
        vm.addConnection(from: a.id, to: b.id)
        vm.connections[0].entryPortOverride = "left"
        vm.connections[0].exitPortOverride = "right"
        vm.selectedNodeIDs = [a.id, b.id]

        vm.copySelectedNodes()
        vm.pasteNodes()

        #expect(vm.nodes.count == 4)
        let pastedA = vm.nodes.first { $0.name == "A" && $0.id != a.id }!
        #expect(pastedA.dialogue == "hello")
        #expect(pastedA.position == CGPoint(x: 40, y: 40))

        #expect(vm.connections.count == 2)
        let newConn = vm.connections.last!
        #expect(newConn.entryPortOverride == "left")
        #expect(newConn.exitPortOverride == "right")
        #expect(newConn.fromNodeID != a.id)
        #expect(newConn.toNodeID != b.id)
        #expect(vm.nodes.contains { $0.id == newConn.fromNodeID })
        #expect(vm.nodes.contains { $0.id == newConn.toNodeID })

        // newly pasted nodes are selected
        #expect(vm.selectedNodeIDs.count == 2)
    }

    @Test func pasteWithoutPriorCopyIsNoOp() {
        let vm = StoryViewModel()
        vm.pasteNodes()
        #expect(vm.nodes.isEmpty)
    }
}

// MARK: - StoryViewModel: Groups

@MainActor
@Suite("StoryViewModel groups")
struct StoryViewModelGroupTests {

    @Test func addGroupSelectsItAndClearsOtherSelection() {
        let vm = StoryViewModel()
        vm.selectedNodeID = UUID()
        vm.selectedNodeIDs = [UUID()]
        vm.selectedConnectionID = UUID()
        vm.isDrawingGroup = true

        vm.addGroup(worldRect: CGRect(x: 0, y: 0, width: 200, height: 200))

        #expect(vm.groups.count == 1)
        #expect(vm.selectedGroupID == vm.groups[0].id)
        #expect(vm.selectedNodeID == nil)
        #expect(vm.selectedNodeIDs.isEmpty)
        #expect(vm.selectedConnectionID == nil)
        #expect(vm.isDrawingGroup == false)
    }

    @Test func toggleGroupPinFlipsFlag() {
        let vm = StoryViewModel()
        vm.groups = [StoryGroup(rect: CGRect(x: 0, y: 0, width: 100, height: 100))]
        let id = vm.groups[0].id

        vm.toggleGroupPin(id)
        #expect(vm.groups[0].isPinned == true)

        vm.toggleGroupPin(id)
        #expect(vm.groups[0].isPinned == false)
    }

    @Test func moveGroupShiftsOrigin() {
        let vm = StoryViewModel()
        vm.groups = [StoryGroup(rect: CGRect(x: 10, y: 10, width: 100, height: 100))]
        let id = vm.groups[0].id

        vm.moveGroup(id, by: CGSize(width: 5, height: -5))

        #expect(vm.groups[0].rect.origin == CGPoint(x: 15, y: 5))
    }

    @Test func moveGroupWithContentsMovesGroupAndContainedNodes() {
        let vm = StoryViewModel()
        let node = StoryNode(position: CGPoint(x: 20, y: 20))
        vm.nodes = [node]
        vm.groups = [StoryGroup(rect: CGRect(x: 0, y: 0, width: 100, height: 100))]
        let groupID = vm.groups[0].id

        vm.moveGroupWithContents(groupID, by: CGSize(width: 10, height: 10), nodesInside: [node.id])

        #expect(vm.groups[0].rect.origin == CGPoint(x: 10, y: 10))
        #expect(vm.nodes[0].position == CGPoint(x: 30, y: 30))
    }

    @Test func resizeGroupClampsToMinimumSize() {
        let vm = StoryViewModel()
        vm.groups = [StoryGroup(rect: CGRect(x: 0, y: 0, width: 150, height: 100))]
        let id = vm.groups[0].id

        vm.resizeGroup(id, by: CGSize(width: 50, height: 50))
        #expect(vm.groups[0].rect.size == CGSize(width: 200, height: 150))

        vm.resizeGroup(id, by: CGSize(width: -1000, height: -1000))
        #expect(vm.groups[0].rect.size == CGSize(width: 120, height: 80))
    }

    @Test func deleteGroupRemovesItAndClearsSelection() {
        let vm = StoryViewModel()
        vm.groups = [StoryGroup(rect: CGRect(x: 0, y: 0, width: 100, height: 100))]
        let id = vm.groups[0].id
        vm.selectedGroupID = id

        vm.deleteGroup(id)

        #expect(vm.groups.isEmpty)
        #expect(vm.selectedGroupID == nil)
    }

    @Test func renameGroupFallsBackToDefaultWhenEmpty() {
        let vm = StoryViewModel()
        vm.groups = [StoryGroup(rect: CGRect(x: 0, y: 0, width: 100, height: 100))]
        let id = vm.groups[0].id

        vm.renameGroup(id, "")
        #expect(vm.groups[0].name == "Group")

        vm.renameGroup(id, "Act 2")
        #expect(vm.groups[0].name == "Act 2")
    }
}

// MARK: - StoryViewModel: Document state & undo

@MainActor
@Suite("StoryViewModel document state")
struct StoryViewModelDocumentTests {

    @Test func documentTitleDefaultsToUntitled() {
        let vm = StoryViewModel()
        #expect(vm.documentTitle == "Untitled")
    }

    @Test func documentTitleUsesFileNameWithoutExtension() {
        let vm = StoryViewModel()
        vm.currentFileURL = URL(fileURLWithPath: "/tmp/MyStory.mpst")
        #expect(vm.documentTitle == "MyStory")
    }

    @Test func undoAndRedoRestoreAddedNode() {
        let vm = StoryViewModel()
        let undoManager = UndoManager()
        vm.undoManager = undoManager

        vm.addNode(at: CGPoint(x: 100, y: 100))
        #expect(vm.nodes.count == 1)

        undoManager.undo()
        #expect(vm.nodes.isEmpty)

        undoManager.redo()
        #expect(vm.nodes.count == 1)
    }
}
