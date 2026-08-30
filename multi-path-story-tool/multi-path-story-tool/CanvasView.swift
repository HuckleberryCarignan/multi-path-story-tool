import SwiftUI

struct CanvasView: View {
    var vm: StoryViewModel

    @State private var canvasOffset        = CGSize(width: 300, height: 200)
    @State private var panDelta            = CGSize.zero
    @State private var nodeDragOffsets:    [UUID: CGSize]  = [:]
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var groupDragAnchor:    UUID?           = nil
    @State private var groupDragIDs:       Set<UUID>       = []
    @State private var hoverPosition       = CGPoint.zero
    @FocusState private var isFocused: Bool
    @State private var scrollMonitor = CanvasScrollMonitor()

    var effectiveOffset: CGSize {
        CGSize(width: canvasOffset.width  + panDelta.width,
               height: canvasOffset.height + panDelta.height)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CanvasGridView(offset: effectiveOffset)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { v in panDelta = v.translation }
                            .onEnded   { v in
                                canvasOffset.width  += v.translation.width
                                canvasOffset.height += v.translation.height
                                panDelta = .zero
                            }
                    )
                    .onTapGesture {
                        isFocused = true
                        vm.connectingFromNodeID = nil
                        vm.selectedNodeID  = nil
                        vm.selectedNodeIDs = []
                        vm.selectedConnectionID = nil
                    }
                    .onContinuousHover { phase in
                        if case .active(let loc) = phase { hoverPosition = loc }
                    }

                ConnectionLinesView(vm: vm, canvasOffset: effectiveOffset, dragOffsets: nodeDragOffsets)
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(vm.nodes) { node in
                    let drag = nodeDragOffsets[node.id] ?? .zero
                    let cx = effectiveOffset.width  + node.position.x + drag.width  + nodeWidth  / 2
                    let cy = effectiveOffset.height + node.position.y + drag.height + nodeHeight / 2

                    StoryNodeView(node: node, vm: vm)
                        .position(x: cx, y: cy)
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { v in
                                    if nodeDragOffsets[node.id] == nil {
                                        let isGroup = vm.selectedNodeIDs.contains(node.id)
                                                   && vm.selectedNodeIDs.count > 1
                                        if isGroup {
                                            groupDragAnchor = node.id
                                            groupDragIDs    = vm.selectedNodeIDs
                                            for id in groupDragIDs {
                                                if let n = vm.nodes.first(where: { $0.id == id }) {
                                                    dragStartPositions[id] = n.position
                                                }
                                            }
                                        } else {
                                            dragStartPositions[node.id] = node.position
                                        }
                                    }
                                    if groupDragAnchor == node.id {
                                        for id in groupDragIDs { nodeDragOffsets[id] = v.translation }
                                    } else if groupDragAnchor == nil {
                                        nodeDragOffsets[node.id] = v.translation
                                    }
                                }
                                .onEnded { v in
                                    if groupDragAnchor == node.id {
                                        vm.finishGroupDrag(
                                            ids: groupDragIDs,
                                            by: v.translation,
                                            from: dragStartPositions
                                        )
                                        for id in groupDragIDs {
                                            dragStartPositions.removeValue(forKey: id)
                                            nodeDragOffsets.removeValue(forKey: id)
                                        }
                                        groupDragAnchor = nil
                                        groupDragIDs    = []
                                    } else if groupDragAnchor == nil {
                                        let origin = dragStartPositions[node.id] ?? node.position
                                        vm.finishDrag(node.id, by: v.translation, from: origin)
                                        dragStartPositions.removeValue(forKey: node.id)
                                        nodeDragOffsets.removeValue(forKey: node.id)
                                    }
                                }
                        )
                }

                if vm.connectingFromNodeID != nil {
                    ConnectingBanner()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay { scrollIndicatorOverlay(geo: geo) }
            .overlay(alignment: .bottomLeading) { zoomOutButton(geo: geo) }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onAppear {
                isFocused = true
                scrollMonitor.start(
                    onScroll: { dx, dy in
                        canvasOffset.width  += dx
                        canvasOffset.height += dy
                    },
                    onCommandClick: {
                        let pos = CGPoint(
                            x: hoverPosition.x - effectiveOffset.width,
                            y: hoverPosition.y - effectiveOffset.height
                        )
                        let overNode = vm.nodes.contains { node in
                            CGRect(x: node.position.x, y: node.position.y,
                                   width: nodeWidth, height: nodeHeight).contains(pos)
                        }
                        guard !overNode, vm.addNodeOnCommandClick else { return false }
                        vm.addNode(at: pos)
                        return true
                    }
                )
            }
            .onChange(of: vm.selectedConnectionID) { _, newID in
                if newID != nil { isFocused = true }
            }
            .onDeleteCommand {
                if let id = vm.selectedConnectionID {
                    vm.removeConnection(id)
                }
            }
            .onHover { hovering in scrollMonitor.isMouseOverCanvas = hovering }
            .onDisappear { scrollMonitor.stop() }
        }
    }

    @ViewBuilder
    private func zoomOutButton(geo: GeometryProxy) -> some View {
        let nodes           = vm.nodes
        let selectedNodeIDs = vm.selectedNodeIDs
        let offset          = effectiveOffset

        if vm.showZoomOut, !nodes.isEmpty {
            let pad: CGFloat = 40
            let worldBounds = nodes
                .map(\.rect)
                .dropFirst()
                .reduce(nodes[0].rect) { $0.union($1) }
                .insetBy(dx: -pad, dy: -pad)

            let miniW = max(120, min(geo.size.width  * 0.18, 220))
            let miniH = max(90,  min(geo.size.height * 0.18, 165))
            let scale    = min(miniW / worldBounds.width, miniH / worldBounds.height)
            let ox       = (miniW - worldBounds.width  * scale) / 2
            let oy       = (miniH - worldBounds.height * scale) / 2

            Canvas { ctx, _ in
                // Draw each node as a small rectangle
                for node in nodes {
                    let x = (node.position.x - worldBounds.minX) * scale + ox
                    let y = (node.position.y - worldBounds.minY) * scale + oy
                    let rect = CGRect(x: x, y: y,
                                      width:  nodeWidth  * scale,
                                      height: nodeHeight * scale)
                    let isSelected = selectedNodeIDs.contains(node.id)
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: isSelected ? .color(.yellow) : .color(.primary.opacity(0.45))
                    )
                    if isSelected {
                        ctx.stroke(
                            Path(roundedRect: rect, cornerRadius: 2),
                            with: .color(.yellow),
                            lineWidth: 1.5
                        )
                    }
                }

                // Draw the current viewport as a tinted rect
                let vpX = (-offset.width  - worldBounds.minX) * scale + ox
                let vpY = (-offset.height - worldBounds.minY) * scale + oy
                let vpRect = CGRect(x: vpX, y: vpY,
                                    width:  geo.size.width  * scale,
                                    height: geo.size.height * scale)
                ctx.fill(
                    Path(roundedRect: vpRect, cornerRadius: 2),
                    with: .color(.accentColor.opacity(0.12))
                )
                ctx.stroke(
                    Path(roundedRect: vpRect, cornerRadius: 2),
                    with: .color(.accentColor.opacity(0.7)),
                    lineWidth: 1
                )
            }
            .frame(width: miniW, height: miniH)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            .padding(12)
        }
    }

    @ViewBuilder
    private func scrollIndicatorOverlay(geo: GeometryProxy) -> some View {
        // Read from vm in the @ViewBuilder scope so @Observable tracks changes
        let nodes  = vm.nodes
        let offset = effectiveOffset

        if !nodes.isEmpty {
            let edgePad: CGFloat = 60
            let nodesBounds = nodes
                .map(\.rect)
                .dropFirst()
                .reduce(nodes[0].rect) { $0.union($1) }
                .insetBy(dx: -edgePad, dy: -edgePad)

            let visLeft   = -offset.width
            let visTop    = -offset.height
            let visRight  = visLeft + geo.size.width
            let visBottom = visTop  + geo.size.height

            let contentLeft   = min(visLeft,  nodesBounds.minX)
            let contentRight  = max(visRight, nodesBounds.maxX)
            let contentTop    = min(visTop,   nodesBounds.minY)
            let contentBottom = max(visBottom, nodesBounds.maxY)
            let contentWidth  = contentRight - contentLeft
            let contentHeight = contentBottom - contentTop

            let showH = contentWidth  > geo.size.width  + 1
            let showV = contentHeight > geo.size.height + 1

            Canvas { ctx, size in
                let thickness: CGFloat = 6
                let margin: CGFloat    = 4
                let minThumb: CGFloat  = 30
                let cornerR            = thickness / 2

                if showH {
                    let vGap   = showV ? thickness + margin : 0
                    let trackW = size.width - 2 * margin - vGap
                    let thumbW = max(minThumb, trackW * geo.size.width / contentWidth)
                    let travel = contentWidth > geo.size.width
                        ? (visLeft - contentLeft) / (contentWidth - geo.size.width) : 0
                    let thumbX = margin + (trackW - thumbW) * min(1, max(0, travel))
                    let barY   = size.height - thickness - margin

                    ctx.fill(
                        Path(roundedRect: CGRect(x: thumbX, y: barY, width: thumbW, height: thickness),
                             cornerRadius: cornerR),
                        with: .color(.primary.opacity(0.28))
                    )
                }

                if showV {
                    let hGap   = showH ? thickness + margin : 0
                    let trackH = size.height - 2 * margin - hGap
                    let thumbH = max(minThumb, trackH * geo.size.height / contentHeight)
                    let travel = contentHeight > geo.size.height
                        ? (visTop - contentTop) / (contentHeight - geo.size.height) : 0
                    let thumbY = margin + (trackH - thumbH) * min(1, max(0, travel))
                    let barX   = size.width - thickness - margin

                    ctx.fill(
                        Path(roundedRect: CGRect(x: barX, y: thumbY, width: thickness, height: thumbH),
                             cornerRadius: cornerR),
                        with: .color(.primary.opacity(0.28))
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// Monitors NSEvent scroll wheel and right-mouse-down events for the canvas.
// isMouseOverCanvas is set by SwiftUI's .onHover on the canvas ZStack.
// onRightClick returns true if the event was handled (consumed) or false to
// let it propagate — the caller computes node proximity at click-time so
// node context menus always work regardless of where cursor is.
private final class CanvasScrollMonitor {
    var isMouseOverCanvas: Bool = false
    private var scrollMonitor: Any?
    private var clickMonitor: Any?

    func start(
        onScroll: @escaping (CGFloat, CGFloat) -> Void,
        onCommandClick: @escaping () -> Bool
    ) {
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isMouseOverCanvas else { return event }
            onScroll(event.scrollingDeltaX, event.scrollingDeltaY)
            return nil  // consume — prevents macOS rubber-band overlay
        }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, self.isMouseOverCanvas else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            return onCommandClick() ? nil : event
        }
    }

    func stop() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m) }
        if let m = clickMonitor  { NSEvent.removeMonitor(m) }
        scrollMonitor = nil
        clickMonitor  = nil
    }

    deinit { stop() }
}

struct CanvasGridView: View {
    var offset: CGSize

    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 40
            let rawOX = offset.width.truncatingRemainder(dividingBy: spacing)
            let rawOY = offset.height.truncatingRemainder(dividingBy: spacing)
            let ox = rawOX < 0 ? rawOX + spacing : rawOX
            let oy = rawOY < 0 ? rawOY + spacing : rawOY

            var x = ox
            while x < size.width {
                var y = oy
                while y < size.height {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(.primary.opacity(0.1))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

struct ConnectingBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.orange)
            Text("Tap a node to connect \u{2014} or tap the canvas to cancel")
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}
