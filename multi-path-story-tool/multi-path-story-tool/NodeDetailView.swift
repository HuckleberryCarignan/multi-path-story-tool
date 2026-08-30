import SwiftUI

struct NodeDetailView: View {
    @Bindable var vm: StoryViewModel

    var body: some View {
        if let node = vm.selectedNode,
           let idx = vm.nodes.firstIndex(where: { $0.id == node.id }) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Story Entry")
                    .font(.headline)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if vm.showIdentifier {
                            fieldSection(label: "Identifier", icon: "scope") {
                                Text(node.shortID)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        Color(nsColor: .quaternaryLabelColor).opacity(0.3),
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                            }
                        }

                        fieldSection(label: "Entry Title") {
                            TextField("Node name", text: $vm.nodes[idx].name)
                                .textFieldStyle(.roundedBorder)
                        }

                        fieldSection(label: "Dialogue / Story", icon: "text.alignleft") {
                            TextEditor(text: $vm.nodes[idx].dialogue)
                                .frame(minHeight: 160)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(nsColor: .separatorColor))
                                )
                        }

                        fieldSection(label: "Outgoing Options", icon: "arrow.triangle.branch") {
                            outgoingList(for: node)
                        }
                    }
                    .padding(14)
                }
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func fieldSection<C: View>(label: String, icon: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let icon {
                Label(label, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    @ViewBuilder
    private func outgoingList(for node: StoryNode) -> some View {
        let outgoing = vm.outgoingConnections(for: node.id)
        if outgoing.isEmpty {
            Text("No outgoing connections")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(6)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(outgoing.enumerated()), id: \.element.connection.id) { i, item in
                    let letter = i < 26 ? String(UnicodeScalar(65 + i)!) : "\(i + 1)"
                    HStack(alignment: .top, spacing: 10) {
                        Text(letter)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .frame(width: 20, height: 20)
                            .background(
                                Color.accentColor.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            if let target = item.target {
                                Text(target.shortID)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(target.name)
                                    .font(.callout.weight(.medium))
                            } else {
                                Text("Deleted node")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        Spacer()
                        Image(systemName: "link.badge.plus")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(
                        Color(nsColor: .quaternaryLabelColor).opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    // ShiftClickLayer sits on top: intercepts only Shift+clicks (passes
                    // all other clicks through), and never steals first responder so the
                    // TextEditor cursor position is preserved for the link insertion.
                    .overlay(
                        ShiftClickLayer {
                            guard let target = item.target else { return }
                            insertDialogueLink(for: target)
                        }
                    )
                    .help(item.target.map {
                        "Shift-click to insert {\($0.shortID)/\($0.name)} into Dialogue / Story"
                    } ?? "")
                }

                Text("Shift-click an option to inject its link into Dialogue / Story")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    private func insertDialogueLink(for target: StoryNode) {
        let link = "{\(target.shortID)/\(target.name)}"
        // TextEditor stays focused (ShiftClickLayer never steals first responder),
        // so firstResponder is still the NSTextView and insertion lands at the cursor.
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            textView.insertText(link, replacementRange: textView.selectedRange())
        } else if let idx = vm.nodes.firstIndex(where: { $0.id == vm.selectedNodeID }) {
            vm.nodes[idx].dialogue += link
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.dashed")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Select a node\nto view details")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// Transparent AppKit overlay that intercepts Shift+clicks without stealing
// first responder. hitTest returns nil for non-Shift events so they fall
// through to the SwiftUI views underneath unchanged.
private struct ShiftClickLayer: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> Impl { Impl(action: action) }
    func updateNSView(_ v: Impl, context: Context) { v.action = action }

    final class Impl: NSView {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }

        // Never become first responder — TextEditor keeps focus during insertion.
        override var acceptsFirstResponder: Bool { false }

        // Only claim the hit when Shift is held; all other clicks pass through.
        override func hitTest(_ point: NSPoint) -> NSView? {
            NSEvent.modifierFlags.contains(.shift) ? self : nil
        }

        override func mouseDown(with event: NSEvent) {
            action()
            // Not calling super prevents any focus change.
        }
    }
}
