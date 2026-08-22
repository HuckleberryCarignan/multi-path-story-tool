import SwiftUI

/// Draws every parent→child choice connector as a labeled bezier curve,
/// recomputing geometry from the latest collected node frames each time
/// `story.nodes` changes (via SwiftData's Observation support).
struct ConnectorsCanvas: View {
    let story: Story
    let nodeFrames: [UUID: CGRect]

    private var edges: [(choice: Choice, geometry: EdgeGeometry)] {
        var result: [(Choice, EdgeGeometry)] = []
        for node in story.nodes {
            guard let parentFrame = nodeFrames[node.id] else { continue }
            for choice in node.choices.sorted(by: { $0.order < $1.order }) {
                guard let target = choice.targetNode, let childFrame = nodeFrames[target.id] else { continue }
                result.append((choice, EdgeGeometry(parentFrame: parentFrame, childFrame: childFrame)))
            }
        }
        return result
    }

    var body: some View {
        Canvas { context, _ in
            for (choice, geometry) in edges {
                context.stroke(geometry.path, with: .color(.secondary), lineWidth: 2)

                let label = context.resolve(
                    Text(choice.label)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                )
                context.draw(label, at: geometry.midpoint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
