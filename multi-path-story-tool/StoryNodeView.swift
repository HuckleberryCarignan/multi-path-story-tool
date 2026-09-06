import SwiftUI

struct StoryNodeView: View {
    let node: StoryNode
    var vm: StoryViewModel

    @State private var isEditingName = false
    @State private var editingText = ""
    @FocusState private var nameFieldFocused: Bool
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"

    private var isSelected:    Bool { vm.selectedNodeIDs.contains(node.id) }
    private var isSource:      Bool { vm.connectingFromNodeID == node.id }
    private var isTarget:      Bool { vm.connectingFromNodeID != nil && !isSource }
    private var isStartEntry:  Bool { vm.startNodeID == node.id }

    private var textAlignment: TextAlignment {
        vm.rightJustifiedOnCanvas ? .trailing : .leading
    }
    private var stackAlignment: HorizontalAlignment {
        vm.rightJustifiedOnCanvas ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 3) {
            if vm.showCanvasIdentifier {
                Text(node.shortID)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if isEditingName {
                TextField("Name", text: $editingText)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(textAlignment)
                    .textFieldStyle(.plain)
                    .focused($nameFieldFocused)
                    .onSubmit { commitEdit() }
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(node.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: nodeWidth, height: nodeHeight)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isEditingName ? Color.accentColor : borderColor,
                        lineWidth: isEditingName ? 2.5 : borderWidth)
        )
        .overlay(alignment: .topLeading) {
            if isStartEntry {
                Image(systemName: "1.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.green)
                    .offset(x: -6, y: -6)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard vm.connectingFromNodeID == nil else { return }
            startEditing()
        }
        .onTapGesture(count: 1) {
            if let fromID = vm.connectingFromNodeID, fromID != node.id {
                vm.addConnection(from: fromID, to: node.id)
                vm.connectingFromNodeID = nil
            } else if NSEvent.modifierFlags.contains(.shift) {
                vm.toggleSelection(node.id)
            } else {
                vm.selectedNodeID  = node.id
                vm.selectedNodeIDs = [node.id]
                vm.selectedConnectionID = nil
            }
        }
        .contextMenu {
            if !isEditingName { contextMenuContent }
        }
        .onChange(of: isEditingName) { _, editing in
            if editing { nameFieldFocused = true }
        }
    }

    private func startEditing() {
        editingText = node.name
        isEditingName = true
    }

    private func commitEdit() {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        vm.updateNodeName(node.id, trimmed.isEmpty ? node.name : trimmed)
        isEditingName = false
    }

    private var cardBackground: Color {
        if isSource { return Color.orange.opacity(0.18) }
        if isTarget { return Color.accentColor.opacity(0.08) }
        return appearanceMode == "color"
            ? Color.white
            : Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSource   { return .orange }
        if isSelected { return .accentColor }
        if isTarget   { return .accentColor.opacity(0.4) }
        return appearanceMode == "color"
            ? Color(red: 0.68, green: 0.58, blue: 0.90).opacity(0.55)
            : Color(nsColor: .separatorColor)
    }

    private var borderWidth: CGFloat { isSelected || isSource ? 2.5 : 1 }

    @ViewBuilder
    private var contextMenuContent: some View {
        if let fromID = vm.connectingFromNodeID {
            if fromID == node.id {
                Button("Cancel Connection") {
                    vm.connectingFromNodeID = nil
                }
            } else {
                Button("Connect Here") {
                    vm.addConnection(from: fromID, to: node.id)
                    vm.connectingFromNodeID = nil
                }
            }
        } else {
            Button("Select") {
                vm.selectedNodeID  = node.id
                vm.selectedNodeIDs = [node.id]
            }
            Button("Rename") { startEditing() }
            if isStartEntry {
                Button("Remove as Beginning Entry") { vm.startNodeID = nil }
            } else {
                Button("Set as Beginning Entry") { vm.startNodeID = node.id }
            }
            Button("Connect to\u{2026}") {
                vm.selectedNodeID  = node.id
                vm.selectedNodeIDs = [node.id]
                vm.connectingFromNodeID = node.id
            }
            let outgoing = vm.outgoingConnections(for: node.id)
            if !outgoing.isEmpty {
                Divider()
                ForEach(outgoing, id: \.connection.id) { item in
                    Button("Disconnect \u{2192} \(item.target?.name ?? "deleted node")") {
                        vm.removeConnection(item.connection.id)
                    }
                }
            }
            Divider()
            Button("Delete Node", role: .destructive) {
                vm.deleteNode(node.id)
            }
        }
    }
}
