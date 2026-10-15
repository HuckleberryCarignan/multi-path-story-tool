import SwiftUI

// Master index of every distinct, non-blank code used across all Story Entries
// in the document. Lives beside the Story Entry panel so the codes stay handy
// while writing dialogue. Strike-through state is a local scratch aid (not
// part of the saved document) for the user to track which codes they've
// already accounted for.
struct CodeIndexView: View {
    var vm: StoryViewModel
    @Binding var isCollapsed: Bool

    @State private var sortAscending = true
    @State private var crossedOutCodes: Set<String> = []
    @State private var tooltipCode: String?
    @State private var hoverTask: Task<Void, Never>?

    private var sortedCodes: [(code: String, description: String)] {
        var descriptionsByCode: [String: String] = [:]
        for entryCode in vm.nodes.flatMap({ $0.codes }) {
            let code = entryCode.code.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            let description = entryCode.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if descriptionsByCode[code] == nil || descriptionsByCode[code]?.isEmpty == true {
                descriptionsByCode[code] = description
            }
        }
        let entries = descriptionsByCode.map { (code: $0.key, description: $0.value) }
        return sortAscending
            ? entries.sorted { $0.code < $1.code }
            : entries.sorted { $0.code > $1.code }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCollapsed {
                collapsedHeader
            } else {
                expandedHeader

                Divider()

                if sortedCodes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(sortedCodes, id: \.code) { entry in
                                codeRow(entry)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var expandedHeader: some View {
        HStack {
            Button {
                isCollapsed = true
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Collapse Code Word List")

            Text("Code Word List")
                .font(.headline)
            Spacer()
            Button {
                sortAscending.toggle()
            } label: {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
            }
            .buttonStyle(.borderless)
            .help(sortAscending ? "Sorted A to Z — click for Z to A" : "Sorted Z to A — click for A to Z")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: panelHeaderHeight, maxHeight: panelHeaderHeight, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var collapsedHeader: some View {
        VStack(alignment: .leading, spacing: 50) {
            Button {
                isCollapsed = false
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
            }
            .buttonStyle(.borderless)
            .help("Expand Code Word List")

            Text("Code Word List")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.secondary)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 20, height: 130)
        }
        .padding(.top, 14)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func truncatedDescription(_ description: String) -> String {
        guard description.count > 15 else { return description }
        return description.prefix(15) + "..."
    }

    private func codeRow(_ entry: (code: String, description: String)) -> some View {
        let isCrossedOut = crossedOutCodes.contains(entry.code)
        return HStack(spacing: 0) {
            Text(entry.code)
                .font(.system(.body, design: .monospaced))
            if !entry.description.isEmpty {
                Text(" - \(truncatedDescription(entry.description))")
                    .font(.body)
            }
        }
        .strikethrough(isCrossedOut)
        .foregroundStyle(isCrossedOut ? .secondary : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCrossedOut { crossedOutCodes.remove(entry.code) } else { crossedOutCodes.insert(entry.code) }
        }
        .onHover { hovering in
            hoverTask?.cancel()
            if hovering && !entry.description.isEmpty {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !Task.isCancelled {
                        tooltipCode = entry.code
                    }
                }
            } else {
                tooltipCode = nil
            }
        }
        .popover(isPresented: Binding(
            get: { tooltipCode == entry.code },
            set: { isPresented in if !isPresented { tooltipCode = nil } }
        )) {
            Text(entry.description)
                .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No codes yet")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
