import SwiftUI

struct CanvasView: View {
    var vm: StoryViewModel

    @State private var canvasOffset        = CGSize(width: 300, height: 200)
    @State private var panDelta            = CGSize.zero
    @State private var nodeDragOffsets:    [UUID: CGSize]  = [:]
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var groupDragAnchor:    UUID?           = nil
    @State private var groupDragIDs:       Set<UUID>       = []
    @State private var hoverPosition        = CGPoint.zero
    @FocusState private var isFocused: Bool
    @State private var scrollMonitor = CanvasScrollMonitor()
    @State private var canvasScale: CGFloat = 1.0
    @State private var groupBoxDragOffsets:   [UUID: CGSize] = [:]
    @State private var groupBoxResizeOffsets: [UUID: CGSize] = [:]
    @State private var drawGroupStart:        CGPoint?       = nil
    @State private var drawGroupCurrent:      CGPoint?       = nil
    @AppStorage("showTooltips") private var showTooltips: Bool = true

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
                        vm.connectingFromNodeID  = nil
                        vm.selectedNodeID        = nil
                        vm.selectedNodeIDs       = []
                        vm.selectedConnectionID  = nil
                        vm.selectedGroupID       = nil
                        vm.isDrawingGroup        = false
                    }
                    .onContinuousHover { phase in
                        if case .active(let loc) = phase { hoverPosition = loc }
                    }

                // Group boxes — rendered behind nodes so entries always appear on top
                ForEach(vm.groups) { group in
                    GroupBoxCanvasItem(
                        group:            group,
                        vm:               vm,
                        effectiveOffset:  effectiveOffset,
                        canvasScale:      canvasScale,
                        dragOffsets:      $groupBoxDragOffsets,
                        resizeOffsets:    $groupBoxResizeOffsets,
                        nodeDragOffsets:  $nodeDragOffsets,
                        allNodes:         vm.nodes,
                        onRename:         { showRenameGroupAlert(for: $0) }
                    )
                }

                // Draw-in-progress preview
                if vm.isDrawingGroup, let start = drawGroupStart, let cur = drawGroupCurrent {
                    let r = groupRectFrom(start, cur)
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.8),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.05)))
                        .frame(width: max(1, r.width), height: max(1, r.height))
                        .position(x: r.midX, y: r.midY)
                        .allowsHitTesting(false)
                }

                // Transparent overlay that captures all gestures while in drawing mode
                if vm.isDrawingGroup {
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { h in if h { NSCursor.crosshair.push() } else { NSCursor.pop() } }
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { v in
                                    drawGroupStart   = v.startLocation
                                    drawGroupCurrent = CGPoint(
                                        x: v.startLocation.x + v.translation.width,
                                        y: v.startLocation.y + v.translation.height
                                    )
                                }
                                .onEnded { v in
                                    defer { drawGroupStart = nil; drawGroupCurrent = nil }
                                    guard let start = drawGroupStart, let cur = drawGroupCurrent else { return }
                                    let sr = groupRectFrom(start, cur)
                                    guard sr.width > 50 && sr.height > 40 else { vm.isDrawingGroup = false; return }
                                    vm.addGroup(worldRect: CGRect(
                                        x: (sr.minX - effectiveOffset.width)  / canvasScale,
                                        y: (sr.minY - effectiveOffset.height) / canvasScale,
                                        width:  sr.width  / canvasScale,
                                        height: sr.height / canvasScale
                                    ))
                                    // Immediately prompt for a label on the new group
                                    if let newGroup = vm.groups.first(where: { $0.id == vm.selectedGroupID }) {
                                        showRenameGroupAlert(for: newGroup)
                                    }
                                }
                        )
                        .onTapGesture { vm.isDrawingGroup = false }
                }

                // Hit paths behind node cards so node taps win
                ConnectionHitLayer(vm: vm, canvasOffset: effectiveOffset, dragOffsets: nodeDragOffsets, canvasScale: canvasScale)
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(vm.nodes) { node in
                    let drag = nodeDragOffsets[node.id] ?? .zero
                    let s  = canvasScale
                    let cx = effectiveOffset.width  + node.position.x * s + drag.width  + nodeWidth  * s / 2
                    let cy = effectiveOffset.height + node.position.y * s + drag.height + nodeHeight * s / 2

                    StoryNodeView(node: node, vm: vm)
                        .scaleEffect(s)
                        .frame(width: nodeWidth * s, height: nodeHeight * s)
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
                                    let worldDelta = CGSize(
                                        width:  v.translation.width  / canvasScale,
                                        height: v.translation.height / canvasScale
                                    )
                                    if groupDragAnchor == node.id {
                                        vm.finishGroupDrag(
                                            ids: groupDragIDs,
                                            by: worldDelta,
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
                                        vm.finishDrag(node.id, by: worldDelta, from: origin)
                                        dragStartPositions.removeValue(forKey: node.id)
                                        nodeDragOffsets.removeValue(forKey: node.id)
                                    }
                                }
                        )
                }

                ConnectionLinesView(vm: vm, canvasOffset: effectiveOffset, dragOffsets: nodeDragOffsets, canvasScale: canvasScale)
                    .frame(width: geo.size.width, height: geo.size.height)

                if vm.connectingFromNodeID != nil {
                    ConnectingBanner()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay { scrollIndicatorOverlay(geo: geo) }
            .overlay(alignment: .bottomLeading) { zoomOutButton(geo: geo) }
            .overlay(alignment: .bottomTrailing) { zoomControls(geo: geo) }
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
                    onZoom: { factor in
                        let focus    = hoverPosition
                        let newScale = max(0.1, min(5.0, canvasScale * factor))
                        let ratio    = newScale / canvasScale
                        canvasOffset.width  = focus.x - (focus.x - canvasOffset.width  - panDelta.width)  * ratio
                        canvasOffset.height = focus.y - (focus.y - canvasOffset.height - panDelta.height) * ratio
                        panDelta    = .zero
                        canvasScale = newScale
                    },
                    onCommandClick: {
                        let pos = CGPoint(
                            x: (hoverPosition.x - effectiveOffset.width)  / canvasScale,
                            y: (hoverPosition.y - effectiveOffset.height) / canvasScale
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
                if let id = vm.selectedGroupID {
                    vm.deleteGroup(id)
                } else if let id = vm.selectedConnectionID {
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
                let vpX = (-offset.width  / canvasScale - worldBounds.minX) * scale + ox
                let vpY = (-offset.height / canvasScale - worldBounds.minY) * scale + oy
                let vpRect = CGRect(x: vpX, y: vpY,
                                    width:  geo.size.width  / canvasScale * scale,
                                    height: geo.size.height / canvasScale * scale)
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

            // Work in world space so calculations are consistent at any zoom level.
            let vpW = geo.size.width  / canvasScale
            let vpH = geo.size.height / canvasScale
            let visLeft   = -offset.width  / canvasScale
            let visTop    = -offset.height / canvasScale
            let visRight  = visLeft + vpW
            let visBottom = visTop  + vpH

            let contentLeft   = min(visLeft,  nodesBounds.minX)
            let contentRight  = max(visRight, nodesBounds.maxX)
            let contentTop    = min(visTop,   nodesBounds.minY)
            let contentBottom = max(visBottom, nodesBounds.maxY)
            let contentWidth  = contentRight - contentLeft
            let contentHeight = contentBottom - contentTop

            let showH = contentWidth  > vpW + 1
            let showV = contentHeight > vpH + 1

            Canvas { ctx, size in
                let thickness: CGFloat = 6
                let margin: CGFloat    = 4
                let minThumb: CGFloat  = 30
                let cornerR            = thickness / 2

                if showH {
                    let vGap   = showV ? thickness + margin : 0
                    let trackW = size.width - 2 * margin - vGap
                    let thumbW = max(minThumb, trackW * vpW / contentWidth)
                    let travel = contentWidth > vpW
                        ? (visLeft - contentLeft) / (contentWidth - vpW) : 0
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
                    let thumbH = max(minThumb, trackH * vpH / contentHeight)
                    let travel = contentHeight > vpH
                        ? (visTop - contentTop) / (contentHeight - vpH) : 0
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

    @ViewBuilder
    private func zoomControls(geo: GeometryProxy) -> some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    applyZoom(factor: 1 / 1.25, centeredOn: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                }
            } label: {
                Image(systemName: "minus").frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(canvasScale <= 0.11)
            .help(showTooltips ? "Zoom out" : "")

            Text("\(Int((canvasScale * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 40)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        applyZoom(factor: 1.0 / canvasScale,
                                  centeredOn: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                    }
                }
                .help(showTooltips ? "Click to reset zoom to 100%" : "")

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    applyZoom(factor: 1.25, centeredOn: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                }
            } label: {
                Image(systemName: "plus").frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(canvasScale >= 4.99)
            .help(showTooltips ? "Zoom in" : "")

            Divider().frame(height: 14)

            Button {
                withAnimation(.easeOut(duration: 0.2)) { zoomToFit(size: geo.size) }
            } label: {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass").frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(vm.nodes.isEmpty)
            .help(showTooltips ? "Zoom to fit all entries in view" : "")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5))
        .padding(12)
    }

    private func applyZoom(factor: CGFloat, centeredOn focus: CGPoint) {
        let newScale = max(0.1, min(5.0, canvasScale * factor))
        let ratio    = newScale / canvasScale
        canvasOffset.width  = focus.x - (focus.x - effectiveOffset.width)  * ratio
        canvasOffset.height = focus.y - (focus.y - effectiveOffset.height) * ratio
        panDelta    = .zero
        canvasScale = newScale
    }

    private func groupRectFrom(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func showRenameGroupAlert(for group: StoryGroup) {
        let alert = NSAlert()
        alert.messageText = "Rename Group"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        tf.stringValue = group.name
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        if alert.runModal() == .alertFirstButtonReturn {
            vm.renameGroup(group.id, tf.stringValue)
        }
    }

    private func zoomToFit(size: CGSize) {
        guard !vm.nodes.isEmpty else { return }
        let pad: CGFloat = 60
        let worldBounds  = vm.nodes.map(\.rect).dropFirst()
            .reduce(vm.nodes[0].rect) { $0.union($1) }
            .insetBy(dx: -pad, dy: -pad)
        let newScale = min(size.width / worldBounds.width,
                           size.height / worldBounds.height,
                           2.0)
        canvasScale  = max(0.1, newScale)
        canvasOffset = CGSize(
            width:  (size.width  - worldBounds.width  * canvasScale) / 2 - worldBounds.minX * canvasScale,
            height: (size.height - worldBounds.height * canvasScale) / 2 - worldBounds.minY * canvasScale
        )
        panDelta = .zero
    }
}

// Monitors NSEvent scroll wheel and right-mouse-down events for the canvas.
// isMouseOverCanvas is set by SwiftUI's .onHover on the canvas ZStack.
// onRightClick returns true if the event was handled (consumed) or false to
// let it propagate — the caller computes node proximity at click-time so
// node context menus always work regardless of where cursor is.
private final class CanvasScrollMonitor {
    var isMouseOverCanvas: Bool = false
    private var scrollMonitor:  Any?
    private var clickMonitor:   Any?
    private var magnifyMonitor: Any?

    func start(
        onScroll: @escaping (CGFloat, CGFloat) -> Void,
        onZoom: @escaping (CGFloat) -> Void,
        onCommandClick: @escaping () -> Bool
    ) {
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isMouseOverCanvas else { return event }
            if event.modifierFlags.contains(.command) {
                // Cmd+scroll = zoom; scale speed differently for trackpad vs mouse wheel
                let raw = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 8
                onZoom(pow(0.99, raw))
                return nil
            }
            onScroll(event.scrollingDeltaX, event.scrollingDeltaY)
            return nil  // consume — prevents macOS rubber-band overlay
        }

        // Trackpad pinch-to-zoom
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self, self.isMouseOverCanvas else { return event }
            onZoom(1 + event.magnification)
            return nil
        }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, self.isMouseOverCanvas else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            return onCommandClick() ? nil : event
        }
    }

    func stop() {
        if let m = scrollMonitor  { NSEvent.removeMonitor(m) }
        if let m = clickMonitor   { NSEvent.removeMonitor(m) }
        if let m = magnifyMonitor { NSEvent.removeMonitor(m) }
        scrollMonitor  = nil
        clickMonitor   = nil
        magnifyMonitor = nil
    }

    deinit { stop() }
}

struct CanvasGridView: View {
    var offset: CGSize
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"

    private var dotColor: Color {
        appearanceMode == "color"
            ? Color(red: 0.62, green: 0.52, blue: 0.82).opacity(0.40)
            : .primary.opacity(0.1)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if appearanceMode == "color" {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.84, blue: 0.88),
                    Color(red: 0.88, green: 0.85, blue: 0.99),
                    Color(red: 0.82, green: 0.96, blue: 0.90),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }

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
                        with: .color(dotColor)
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .background(backgroundView)
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
