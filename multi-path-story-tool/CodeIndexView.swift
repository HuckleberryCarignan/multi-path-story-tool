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

    private var sortedCodes: [String] {
        let unique = Set(
            vm.nodes.flatMap { $0.codes.map { $0.code } }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return sortAscending ? unique.sorted() : unique.sorted(by: >)
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
                            ForEach(sortedCodes, id: \.self) { code in
                                codeRow(code)
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func codeRow(_ code: String) -> some View {
        let isCrossedOut = crossedOutCodes.contains(code)
        return Text(code)
            .font(.system(.body, design: .monospaced))
            .strikethrough(isCrossedOut)
            .foregroundStyle(isCrossedOut ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCrossedOut { crossedOutCodes.remove(code) } else { crossedOutCodes.insert(code) }
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
