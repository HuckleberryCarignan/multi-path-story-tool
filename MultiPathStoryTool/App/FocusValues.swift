import SwiftUI

private struct FocusedStoryKey: FocusedValueKey {
    typealias Value = Story
}

private struct FocusedStoryNodeIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    /// The `Story` owning the currently focused node's `TextEditor`, published
    /// per-window from `StoryCanvasView` so Cmd+D scopes correctly across
    /// multiple open documents.
    var focusedStory: Story? {
        get { self[FocusedStoryKey.self] }
        set { self[FocusedStoryKey.self] = newValue }
    }

    /// The `id` of the `StoryNode` whose passage `TextEditor` currently has
    /// keyboard focus.
    var focusedStoryNodeID: UUID? {
        get { self[FocusedStoryNodeIDKey.self] }
        set { self[FocusedStoryNodeIDKey.self] = newValue }
    }
}

/// `focusedSceneValue(_:_:)` requires a non-optional value for its keypath's
/// wrapped type, but the currently-focused node id is itself optional (no
/// node may be focused). This modifier only publishes the focused value when
/// one exists, leaving `focusedStoryNodeID` unset (nil) otherwise.
struct FocusedNodeIDModifier: ViewModifier {
    let nodeID: UUID?

    func body(content: Content) -> some View {
        if let nodeID {
            content.focusedSceneValue(\.focusedStoryNodeID, nodeID)
        } else {
            content
        }
    }
}
