import SwiftUI

struct NodeDetailView: View {
    @Bindable var vm: StoryViewModel
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"

    var body: some View {
        if let node = vm.selectedNode,
           let idx = vm.nodes.firstIndex(where: { $0.id == node.id }) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Story Entry")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: panelHeaderHeight, maxHeight: panelHeaderHeight, alignment: .leading)
                    .background(appearanceMode == "color"
                        ? Color(red: 0.82, green: 0.93, blue: 1.0)
                        : Color(nsColor: .controlBackgroundColor))

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

                        fieldSection(label: "Beginning Entry", icon: "1.circle") {
                            if vm.startNodeID == node.id {
                                HStack {
                                    Label("Set as beginning", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.callout)
                                    Spacer()
                                    Button("Remove") { vm.startNodeID = nil }
                                        .buttonStyle(.borderless)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            } else {
                                Button {
                                    vm.startNodeID = node.id
                                } label: {
                                    Label("Set as Beginning Entry", systemImage: "1.circle")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if vm.showEntryCodesSection {
                            entryCodesSection(node: node, idx: idx)
                        }

                        fieldSection(label: "Dialogue / Story", icon: "text.alignleft",
                                    trailingButton: {
                            HStack(spacing: 10) {
                                FocusPreservingIconButton(systemName: "list.bullet") {
                                    toggleBulletList(text: $vm.nodes[idx].dialogue)
                                }
                                .help("Toggle bullet list")

                                Button {
                                    vm.isDialogueExpanded = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Expand editor")
                            }
                        }) {
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
    private func fieldSection<C: View, B: View>(
        label: String, icon: String? = nil,
        @ViewBuilder trailingButton: () -> B = { EmptyView() },
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let icon {
                    Label(label, systemImage: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailingButton()
            }
            content()
        }
    }

    @ViewBuilder
    private func entryCodesSection(node: StoryNode, idx: Int) -> some View {
        let atMax = vm.nodes[idx].codes.count >= vm.maxEntryCodes
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    vm.addCode(to: node.id)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(atMax)
                .foregroundStyle(atMax ? .tertiary : .primary)
                .help(atMax ? "Maximum of \(vm.maxEntryCodes) codes reached" : "Add code")

                Text("Entry Codes Found")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !vm.nodes[idx].codes.isEmpty {
                HStack(spacing: 6) {
                    Text("Code")
                        .frame(width: 44, alignment: .leading)
                    Text("Description")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.leading, 22)

                ForEach(Array(vm.nodes[idx].codes.enumerated()), id: \.element.id) { cIdx, entry in
                    HStack(spacing: 6) {
                        TextField("", text: $vm.nodes[idx].codes[cIdx].code)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: vm.nodes[idx].codes[cIdx].code) { _, newValue in
                                let sanitized = String(newValue.uppercased()
                                    .filter { $0.isLetter || $0.isNumber }
                                    .prefix(vm.maxCodeLength))
                                if sanitized != newValue { vm.nodes[idx].codes[cIdx].code = sanitized }
                            }

                        Button {
                            vm.removeCode(entry.id, from: node.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                        .help("Remove code")

                        TextField("", text: $vm.nodes[idx].codes[cIdx].description)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: vm.nodes[idx].codes[cIdx].description) { _, newValue in
                                if newValue.count > 30 {
                                    vm.nodes[idx].codes[cIdx].description = String(newValue.prefix(30))
                                }
                            }
                    }
                }
            }
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
                    let link = item.target.map { "{\($0.shortID)/\($0.name)}" }
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
                    // Drag the row's link text into the Dialogue / Story TextEditor;
                    // NSTextView accepts plain-text drops at the drop location natively.
                    .draggable(link ?? "")
                    .help(link.map {
                        "Shift-click, or drag, to insert \($0) into Dialogue / Story"
                    } ?? "")
                }

                Text("Shift-click or drag an option to insert its link into Dialogue / Story")
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

// Icon button that never becomes first responder, so clicking it doesn't
// steal focus from the Dialogue / Story TextEditor. Used by the bullet-list
// toggle, which needs the text view's selection to still be current when
// its action runs.
struct FocusPreservingIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Representable(systemName: systemName, action: action)
            .frame(width: 14, height: 14)
    }

    private struct Representable: NSViewRepresentable {
        let systemName: String
        let action: () -> Void

        func makeNSView(context: Context) -> Impl { Impl(systemName: systemName, action: action) }
        func updateNSView(_ v: Impl, context: Context) { v.action = action }

        final class Impl: NSView {
            var action: () -> Void
            private let imageView = NSImageView()

            init(systemName: String, action: @escaping () -> Void) {
                self.action = action
                super.init(frame: .zero)
                imageView.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
                imageView.contentTintColor = .secondaryLabelColor
                imageView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(imageView)
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    imageView.topAnchor.constraint(equalTo: topAnchor),
                    imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
                ])
            }
            required init?(coder: NSCoder) { fatalError() }

            override var acceptsFirstResponder: Bool { false }
            override func mouseDown(with event: NSEvent) { action() }
        }
    }
}

// Toggles a "• " bullet prefix on the line(s) touched by the current
// selection in the focused NSTextView (mirrors insertDialogueLink's approach
// above). Falls back to appending a bullet directly to `text` if no text
// view is focused.
func toggleBulletList(text: Binding<String>) {
    guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
        text.wrappedValue += (text.wrappedValue.isEmpty ? "" : "\n") + "• "
        return
    }

    let full = textView.string as NSString
    let lineRange = full.lineRange(for: textView.selectedRange())
    var body = full.substring(with: lineRange)
    let hasTrailingNewline = body.hasSuffix("\n")
    if hasTrailingNewline { body.removeLast() }

    let lines = body.components(separatedBy: "\n")
    let alreadyBulleted = lines.contains { $0.hasPrefix("• ") }
    let newLines = alreadyBulleted
        ? lines.map { $0.hasPrefix("• ") ? String($0.dropFirst(2)) : $0 }
        : lines.map { "• " + $0 }

    var newText = newLines.joined(separator: "\n")
    if hasTrailingNewline { newText += "\n" }
    textView.insertText(newText, replacementRange: lineRange)
}
