import SwiftData
import XCTest

@testable import MultiPathStoryTool

final class RenumberingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Story.self, StoryNode.self, Choice.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    private func makeStory() -> (Story, StoryNode) {
        let story = Story()
        let root = StoryNode()
        root.displayNumber = story.startingNumber
        story.rootNodeID = root.id
        story.nodes = [root]
        context.insert(story)
        return (story, root)
    }

    func testRootNumbering() {
        let (story, root) = makeStory()
        story.renumberTree()
        XCTAssertEqual(root.displayNumber, story.startingNumber)
    }

    func testSequentialChildNumbering() {
        let (story, root) = makeStory()

        let child1 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        let child2 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)

        XCTAssertEqual(root.displayNumber, 1)
        XCTAssertEqual(child1.displayNumber, 2)
        XCTAssertEqual(child2.displayNumber, 3)
    }

    func testGrandchildInsertionShiftsLaterSiblingNumbers() {
        let (story, root) = makeStory()

        let child1 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        let child2 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        XCTAssertEqual(child2.displayNumber, 3)

        _ = StoryMutator.addChoiceAndChild(to: child1, in: story, context: context)

        XCTAssertEqual(child2.displayNumber, 4, "Later root-level sibling should shift after a grandchild is inserted earlier in the DFS order")
    }

    func testChoiceLabelIsOneIndexed() {
        let (story, root) = makeStory()

        _ = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        _ = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)

        let labels = root.choices.sorted { $0.order < $1.order }.map(\.label)
        XCTAssertEqual(labels, ["1", "2"])
    }

    func testAddChoiceAppendsNumberedLineToParentPassage() {
        let (story, root) = makeStory()
        root.passageText = "You stand at a crossroads."

        _ = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)

        XCTAssertTrue(root.passageText.hasSuffix("1. "))
    }

    func testDeleteNodeCompactsSiblingOrderAndRenumbers() {
        let (story, root) = makeStory()

        let child1 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        let child2 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        let child3 = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)

        StoryMutator.deleteNode(child2, in: story, context: context)

        let remainingChoices = root.choices.sorted { $0.order < $1.order }
        XCTAssertEqual(remainingChoices.map(\.order), [0, 1])
        XCTAssertEqual(remainingChoices.compactMap { $0.targetNode?.id }, [child1.id, child3.id])
        XCTAssertEqual(child3.displayNumber, 3)
    }

    func testDeleteSubtreeRemovesDescendants() {
        let (story, root) = makeStory()

        let child = StoryMutator.addChoiceAndChild(to: root, in: story, context: context)
        let grandchild = StoryMutator.addChoiceAndChild(to: child, in: story, context: context)

        StoryMutator.deleteNode(child, in: story, context: context)

        XCTAssertFalse(story.nodes.contains { $0.id == child.id })
        XCTAssertFalse(story.nodes.contains { $0.id == grandchild.id })
        XCTAssertEqual(story.nodes.count, 1)
        XCTAssertTrue(root.choices.isEmpty)
    }

    func testDeletingRootNodeIsANoOp() {
        let (story, root) = makeStory()
        story.renumberTree()

        StoryMutator.deleteNode(root, in: story, context: context)

        XCTAssertEqual(story.nodes.count, 1)
        XCTAssertEqual(root.displayNumber, story.startingNumber)
    }
}
