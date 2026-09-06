import SwiftUI

struct ContentView: View {
    @State private var vm = StoryViewModel()
    @State private var detailWidth: CGFloat = 280
    @State private var dragStartWidth: CGFloat = 280
    @State private var isDraggingDivider = false
    @State private var showingSettings = false
    @Environment(\.undoManager) private var undoManager
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"
    @AppStorage("showTooltips") private var showTooltips: Bool = true

    private let minPanelWidth: CGFloat = 200
    private let maxPanelWidth: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            if vm.rightJustifiedOnCanvas {
                NodeDetailView(vm: vm)
                    .frame(width: detailWidth)
                dividerHandle
                canvasPanel
            } else {
                canvasPanel
                dividerHandle
                NodeDetailView(vm: vm)
                    .frame(width: detailWidth)
            }
        }
        .frame(minWidth: 860, minHeight: 520)
        .preferredColorScheme(appearanceMode == "dark" ? .dark : .light)
        .onAppear { vm.undoManager = undoManager }
        .onChange(of: undoManager) { _, um in vm.undoManager = um }
        .overlay {
            if vm.isDialogueExpanded,
               let node = vm.selectedNode,
               let idx = vm.nodes.firstIndex(where: { $0.id == node.id }) {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { vm.isDialogueExpanded = false }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Dialogue / Story", systemImage: "text.alignleft")
                            .font(.headline)
                        Spacer()
                        Button {
                            vm.isDialogueExpanded = false
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        .help("Collapse editor")
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                    Divider()

                    TextEditor(text: $vm.nodes[idx].dialogue)
                        .padding(12)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
                .padding(48)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button { vm.newDocument() } label: {
                        Label("New Story", systemImage: "doc.badge.plus")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])

                    Button { vm.openDocument() } label: {
                        Label("Open Story", systemImage: "folder")
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Divider()

                    Button { vm.saveDocument() } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)

                    Button { vm.saveDocumentAs() } label: {
                        Label("Save As", systemImage: "square.and.arrow.down.on.square")
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])

                    Divider()

                    Button { vm.exportAsText() } label: {
                        Label("Export Randomized Story As Text", systemImage: "doc.plaintext")
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                } label: {
                    Label("File", systemImage: "doc")
                }
                .help(showTooltips ? "New, open, save, and export story files" : "")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 5) {
                    if vm.hasUnsavedChanges {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary)
                            .help(showTooltips ? "Unsaved changes" : "")
                    }
                    Text(vm.documentTitle)
                        .font(.subheadline.weight(.medium))
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if vm.connectingFromNodeID != nil {
                    Button {
                        vm.connectingFromNodeID = nil
                    } label: {
                        Label("Cancel Connect", systemImage: "xmark.circle")
                    }
                    .tint(.orange)
                    .help(showTooltips ? "Cancel the active connection" : "")
                }

                if vm.selectedConnectionID != nil {
                    Button(role: .destructive) {
                        if let id = vm.selectedConnectionID {
                            vm.removeConnection(id)
                        }
                    } label: {
                        Label("Delete Connection", systemImage: "minus.circle")
                    }
                    .help(showTooltips ? "Delete the selected connection" : "")
                }

                Button {
                    vm.isDrawingGroup.toggle()
                } label: {
                    Label("Draw Group Box", systemImage: "rectangle.dashed")
                }
                .keyboardShortcut("g", modifiers: .command)
                .tint(vm.isDrawingGroup ? .orange : nil)
                .help(showTooltips ? "Draw a box to group Story Entries together (⌘G)" : "")

                Button {
                    addNode()
                } label: {
                    Label("Add Node", systemImage: "plus.square")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help(showTooltips ? "Add a new Story Entry below the selected one (⌘N)" : "")

                Button {
                    showingSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .popover(isPresented: $showingSettings, arrowEdge: .top) {
                    SettingsView(vm: vm)
                }
                .help(showTooltips ? "Open settings" : "")
            }
        }
    }

    private var canvasPanel: some View {
        VStack(spacing: 0) {
            Text("Story Canvas")
                .font(.headline)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(appearanceMode == "color"
                    ? Color(red: 1.00, green: 0.84, blue: 0.88)
                    : Color(nsColor: .controlBackgroundColor))
            Divider()
            CanvasView(vm: vm)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let gap: CGFloat = 60
        let pos: CGPoint
        if let selected = vm.selectedNode {
            pos = CGPoint(x: selected.position.x,
                          y: selected.position.y + selected.height + gap)
        } else if let bottomNode = vm.nodes.max(by: { ($0.position.y + $0.height) < ($1.position.y + $1.height) }) {
            pos = CGPoint(x: bottomNode.position.x,
                          y: bottomNode.position.y + bottomNode.height + gap)
        } else {
            pos = CGPoint(x: 60, y: 60)
        }
        vm.addNode(at: pos)
    }
}

#Preview {
    ContentView()
}
