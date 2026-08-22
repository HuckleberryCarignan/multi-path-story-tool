import SwiftUI

/// Routes Cmd+D via the menu-bar key-equivalent path rather than
/// `.onKeyPress` on the `TextEditor`, which is unreliable because key events
/// are consumed by the NSTextView-backed control before SwiftUI sees them.
/// Cmd+D has no default Cocoa text-editing binding, so there's no conflict.
struct StoryCommands: Commands {
    @FocusedValue(\.focusedStory) private var focusedStory
    @FocusedValue(\.focusedStoryNodeID) private var focusedStoryNodeID

    var body: some Commands {
        CommandMenu("Story") {
            Button("Add Choice & Branch") {
                addChoiceAndBranch()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(focusedStory == nil || focusedStoryNodeID == nil)
        }
    }

    private func addChoiceAndBranch() {
        guard let story = focusedStory,
              let nodeID = focusedStoryNodeID,
              let node = story.nodes.first(where: { $0.id == nodeID }),
              let context = story.modelContext else { return }
        StoryMutator.addChoiceAndChild(to: node, in: story, context: context)
    }
}
