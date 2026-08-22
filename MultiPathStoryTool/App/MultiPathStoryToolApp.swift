import SwiftData
import SwiftUI

@main
struct MultiPathStoryToolApp: App {
    var body: some Scene {
        DocumentGroup(editing: Story.self, contentType: .storyDocument) {
            StoryRootView()
        } prepareDocument: { context in
            let story = Story()
            let root = StoryNode()
            root.displayNumber = story.startingNumber
            root.passageText = "Once upon a time..."
            story.rootNodeID = root.id
            story.nodes = [root]
            context.insert(story)
        }
        .commands {
            StoryCommands()
        }
    }
}
