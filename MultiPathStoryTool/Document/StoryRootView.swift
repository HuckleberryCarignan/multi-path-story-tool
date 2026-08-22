import SwiftData
import SwiftUI

/// The editor view registered with `DocumentGroup`. Each document's
/// `ModelContainer` holds exactly one `Story`, inserted by `prepareDocument`.
struct StoryRootView: View {
    @Query private var stories: [Story]

    var body: some View {
        if let story = stories.first {
            StoryCanvasView(story: story)
        } else {
            ContentUnavailableView("No Story", systemImage: "doc.text")
        }
    }
}
