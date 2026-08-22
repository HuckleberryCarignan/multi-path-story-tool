import SwiftData
import SwiftUI

struct StoryCanvasView: View {
    let story: Story

    @FocusState private var focusedNodeID: UUID?

    @State private var transform = CanvasTransform()
    @State private var nodeFrames: [UUID: CGRect] = [:]
    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0

    var body: some View {
        GeometryReader { _ in
            ZStack {
                GridBackground(transform: transform)

                ConnectorsCanvas(story: story, nodeFrames: nodeFrames)

                ForEach(story.nodes) { node in
                    NodeView(
                        node: node,
                        transform: transform,
                        focusedNodeID: $focusedNodeID,
                        isRoot: node.id == story.rootNodeID,
                        onDelete: { deleteNode(node) }
                    )
                }
            }
            .coordinateSpace(name: "canvas")
            .contentShape(Rectangle())
            .gesture(panGesture)
            .simultaneousGesture(magnifyGesture)
            .onPreferenceChange(NodeFramePreferenceKey.self) { nodeFrames = $0 }
        }
        .clipped()
        .focusedSceneValue(\.focusedStory, story)
        .modifier(FocusedNodeIDModifier(nodeID: focusedNodeID))
        .onAppear {
            transform.offset = CGPoint(x: story.canvasOffsetX, y: story.canvasOffsetY)
            transform.scale = story.canvasScale
        }
    }

    /// Pan the background. `.gesture` (not `.highPriorityGesture`) so that
    /// `NodeView`'s own `.highPriorityGesture` drag wins when the user starts
    /// a drag on a node instead of empty canvas.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("canvas"))
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - lastPanTranslation.width,
                    height: value.translation.height - lastPanTranslation.height
                )
                transform.offset.x += delta.width
                transform.offset.y += delta.height
                lastPanTranslation = value.translation
            }
            .onEnded { _ in
                lastPanTranslation = .zero
                story.canvasOffsetX = transform.offset.x
                story.canvasOffsetY = transform.offset.y
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = transform.scale * (value.magnification / lastMagnification)
                transform.scale = min(3.0, max(0.25, newScale))
                lastMagnification = value.magnification
            }
            .onEnded { _ in
                lastMagnification = 1.0
                story.canvasScale = transform.scale
            }
    }

    private func deleteNode(_ node: StoryNode) {
        guard let context = story.modelContext else { return }
        if focusedNodeID == node.id {
            focusedNodeID = nil
        }
        StoryMutator.deleteNode(node, in: story, context: context)
    }
}
