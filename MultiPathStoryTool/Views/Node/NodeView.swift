import SwiftData
import SwiftUI

struct NodeView: View {
    @Bindable var node: StoryNode
    let transform: CanvasTransform
    var focusedNodeID: FocusState<UUID?>.Binding
    let isRoot: Bool
    let onDelete: () -> Void

    @State private var dragTranslation: CGSize = .zero

    private var isFocused: Bool {
        focusedNodeID.wrappedValue == node.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            TextEditor(text: $node.passageText)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .focused(focusedNodeID, equals: node.id)

            if !node.choices.isEmpty {
                Divider()
                choiceList
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isFocused ? 2 : 1)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NodeFramePreferenceKey.self,
                    value: [node.id: proxy.frame(in: .named("canvas"))]
                )
            }
        )
        .position(
            x: transform.toScreen(node.position).x + dragTranslation.width,
            y: transform.toScreen(node.position).y + dragTranslation.height
        )
        .scaleEffect(transform.scale)
        .highPriorityGesture(dragGesture)
    }

    private var header: some View {
        HStack {
            Text("\(node.displayNumber)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            if !isRoot {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var choiceList: some View {
        ForEach(node.choices.sorted(by: { $0.order < $1.order })) { choice in
            HStack(alignment: .top, spacing: 4) {
                Text("\(choice.label).")
                    .font(.caption.bold())
                Text(choice.targetNode?.passageText.prefix(40) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .named("canvas"))
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                let delta = transform.modelDelta(fromScreenDelta: value.translation)
                node.position = CGPoint(x: node.position.x + delta.width, y: node.position.y + delta.height)
                dragTranslation = .zero
            }
    }
}
