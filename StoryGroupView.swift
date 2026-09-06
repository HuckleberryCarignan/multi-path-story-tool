import SwiftUI

// Purely visual rendering of a group box label + background.
struct StoryGroupItemView: View {
    let group: StoryGroup
    let isSelected: Bool
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(groupColor.opacity(appearanceMode == "color" ? 0.28 : 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? groupColor : groupColor.opacity(appearanceMode == "color" ? 0.7 : 0.4),
                                lineWidth: isSelected ? 2 : 1.5)
                )
                .allowsHitTesting(false)

            // Label pill — sits just inside the top-left corner
            Text(group.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(groupColor)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(groupColor.opacity(appearanceMode == "color" ? 0.35 : 0.15), in: Capsule())
                .overlay(Capsule().stroke(groupColor.opacity(appearanceMode == "color" ? 0.55 : 0.3), lineWidth: 1))
                .padding(8)
                .allowsHitTesting(false)
        }
    }

    private var groupColor: Color { pastelColors[group.colorIndex % pastelColors.count] }
}

// Interactive canvas item: positions, moves, resizes, and pins one group box.
struct GroupBoxCanvasItem: View {
    let group: StoryGroup
    var vm: StoryViewModel
    let effectiveOffset: CGSize
    let canvasScale: CGFloat
    @Binding var dragOffsets:    [UUID: CGSize]
    @Binding var resizeOffsets:  [UUID: CGSize]
    @Binding var nodeDragOffsets: [UUID: CGSize]
    var allNodes: [StoryNode]
    let onRename: (StoryGroup) -> Void

    // IDs of nodes captured at the moment a pinned drag starts.
    @State private var dragPinnedNodeIDs: [UUID] = []
    @AppStorage("showTooltips") private var showTooltips: Bool = true

    private var dragOff:   CGSize { dragOffsets[group.id]   ?? .zero }
    private var resizeOff: CGSize { resizeOffsets[group.id] ?? .zero }
    private var isSelected: Bool  { vm.selectedGroupID == group.id }
    private var groupColor: Color { pastelColors[group.colorIndex % pastelColors.count] }

    private var sw: CGFloat { max(20, group.rect.width  * canvasScale + resizeOff.width) }
    private var sh: CGFloat { max(20, group.rect.height * canvasScale + resizeOff.height) }
    private var sx: CGFloat { effectiveOffset.width  + group.rect.minX * canvasScale + dragOff.width }
    private var sy: CGFloat { effectiveOffset.height + group.rect.minY * canvasScale + dragOff.height }

    var body: some View {
        // Main box
        StoryGroupItemView(group: group, isSelected: isSelected)
            .frame(width: sw, height: sh)
            .contentShape(Rectangle())
            .position(x: sx + sw / 2, y: sy + sh / 2)
            .onTapGesture(count: 2) { onRename(group) }
            .onTapGesture { selectGroup() }
            .gesture(moveDrag)
            .contextMenu {
                Button("Rename\u{2026}") { onRename(group) }
                Divider()
                Button(group.isPinned ? "Unlock Contents" : "Lock Contents") {
                    vm.toggleGroupPin(group.id)
                }
                Divider()
                Button("Delete Group", role: .destructive) { vm.deleteGroup(group.id) }
            }

        // Pin toggle icon — visible when selected or when the group is already pinned.
        // Tapping it toggles the pin state.
        if isSelected || group.isPinned {
            Image(systemName: group.isPinned ? "lock.fill" : "lock.open")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(group.isPinned ? groupColor : groupColor.opacity(0.45))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .position(x: sx + sw - 18, y: sy + 18)
                .onTapGesture { vm.toggleGroupPin(group.id) }
                .help(showTooltips
                      ? (group.isPinned
                         ? "Locked — dragging this group also moves its contents. Tap to unlock."
                         : "Tap to lock contents so they move with the group.")
                      : "")
        }

        // Resize handle at bottom-right corner (only when selected)
        if isSelected {
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                .frame(width: 12, height: 12)
                .position(x: sx + sw, y: sy + sh)
                .gesture(resizeDrag)
                .onHover { h in if h { NSCursor.crosshair.push() } else { NSCursor.pop() } }
        }
    }

    private func selectGroup() {
        vm.selectedGroupID      = group.id
        vm.selectedNodeID       = nil
        vm.selectedNodeIDs      = []
        vm.selectedConnectionID = nil
    }

    // Returns IDs of nodes whose center falls inside the group's world-space rect.
    private func nodesInsideGroup() -> [UUID] {
        allNodes.filter { node in
            let center = CGPoint(x: node.position.x + nodeWidth  / 2,
                                 y: node.position.y + nodeHeight / 2)
            return group.rect.contains(center)
        }.map(\.id)
    }

    private var moveDrag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                // Capture contained nodes once at drag start (before any offset is applied).
                if dragOffsets[group.id] == nil && group.isPinned {
                    dragPinnedNodeIDs = nodesInsideGroup()
                }
                dragOffsets[group.id] = v.translation
                // Apply the same live offset to pinned nodes for a real-time preview.
                if group.isPinned {
                    for id in dragPinnedNodeIDs {
                        nodeDragOffsets[id] = v.translation
                    }
                }
            }
            .onEnded { v in
                let delta = CGSize(
                    width:  v.translation.width  / canvasScale,
                    height: v.translation.height / canvasScale
                )
                if group.isPinned && !dragPinnedNodeIDs.isEmpty {
                    vm.moveGroupWithContents(group.id, by: delta, nodesInside: dragPinnedNodeIDs)
                    for id in dragPinnedNodeIDs { nodeDragOffsets.removeValue(forKey: id) }
                } else {
                    vm.moveGroup(group.id, by: delta)
                }
                dragOffsets.removeValue(forKey: group.id)
                dragPinnedNodeIDs = []
            }
    }

    private var resizeDrag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in resizeOffsets[group.id] = v.translation }
            .onEnded   { v in
                vm.resizeGroup(group.id, by: CGSize(
                    width:  v.translation.width  / canvasScale,
                    height: v.translation.height / canvasScale
                ))
                resizeOffsets.removeValue(forKey: group.id)
            }
    }
}
