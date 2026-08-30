import SwiftUI

struct ContentView: View {
    @State private var vm = StoryViewModel()
    @State private var detailWidth: CGFloat = 280
    @State private var dragStartWidth: CGFloat = 280
    @State private var isDraggingDivider = false
    @State private var showingSettings = false

    private let minPanelWidth: CGFloat = 200
    private let maxPanelWidth: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            if vm.rightJustifiedOnCanvas {
                NodeDetailView(vm: vm)
                    .frame(width: detailWidth)
                dividerHandle
                CanvasView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CanvasView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                dividerHandle
                NodeDetailView(vm: vm)
                    .frame(width: detailWidth)
            }
        }
        .frame(minWidth: 860, minHeight: 520)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if vm.connectingFromNodeID != nil {
                    Button {
                        vm.connectingFromNodeID = nil
                    } label: {
                        Label("Cancel Connect", systemImage: "xmark.circle")
                    }
                    .tint(.orange)
                }

                if vm.selectedConnectionID != nil {
                    Button(role: .destructive) {
                        if let id = vm.selectedConnectionID {
                            vm.removeConnection(id)
                        }
                    } label: {
                        Label("Delete Connection", systemImage: "minus.circle")
                    }
                }

                Button {
                    addNode()
                } label: {
                    Label("Add Node", systemImage: "plus.square")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    showingSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .popover(isPresented: $showingSettings, arrowEdge: .top) {
                    SettingsView(vm: vm)
                }
            }
        }
    }

    private var dividerHandle: some View {
        Color(nsColor: isDraggingDivider ? .controlAccentColor : .separatorColor)
            .frame(width: isDraggingDivider ? 3 : 1)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle().inset(by: -5))
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !isDraggingDivider {
                            isDraggingDivider = true
                            dragStartWidth = detailWidth
                        }
                        let sign: CGFloat = vm.rightJustifiedOnCanvas ? 1 : -1
                        detailWidth = max(minPanelWidth, min(maxPanelWidth,
                                         dragStartWidth + sign * v.translation.width))
                    }
                    .onEnded { _ in isDraggingDivider = false }
            )
    }

    private func addNode() {
        let count = vm.nodes.count
        let col = CGFloat(count % 4)
        let row = CGFloat(count / 4)
        vm.addNode(at: CGPoint(
            x: col * (nodeWidth + 40) + 60,
            y: row * (nodeHeight + 60) + 60
        ))
    }
}

#Preview {
    ContentView()
}
