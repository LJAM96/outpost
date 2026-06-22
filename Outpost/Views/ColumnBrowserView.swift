import SwiftUI

struct ColumnBrowserView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var columns: [ColumnData] = []
    @State private var scrollProxy: ScrollViewProxy?

    struct ColumnData: Identifiable {
        let id = UUID()
        let path: String
        let title: String
        var items: [RemoteItem]
        var selectedIndex: Int?
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedRemote == nil {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(columns.enumerated()), id: \.element.id) { (index, column) in
                                ColumnPane(
                                    column: column,
                                    isLast: index == columns.count - 1,
                                    onSelect: { item in
                                        handleSelection(at: index, item: item)
                                    },
                                    onDoubleClick: { item in
                                        if !item.isDirectory {
                                            viewModel.quickOpenFile(item)
                                        }
                                    },
                                    onContextMenu: { item in }
                                )
                                .frame(width: 220)
                                .id(column.id)

                                Divider()
                            }

                            if columns.isEmpty {
                                Color.clear.frame(width: 220)
                            }
                        }
                        .frame(minHeight: 400)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        loadRoot()
                    }
                    .onChange(of: viewModel.selectedRemote) { _ in
                        loadRoot()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.quaternary)
            Text("No Remote Selected")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadRoot() {
        columns = []
        guard let remote = viewModel.selectedRemote else { return }
        let col = ColumnData(path: "", title: remote.name, items: [], selectedIndex: nil)
        columns = [col]
        Task { await loadColumn(0, path: "") }
    }

    private func loadColumn(_ index: Int, path: String) async {
        guard let remote = viewModel.selectedRemote else { return }
        do {
            let rawItems = try await RcloneService.shared.listFiles(remote: remote.name, path: path)
            let sorted = rawItems.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            columns[index].items = sorted
        } catch {}
    }

    private func handleSelection(at index: Int, item: RemoteItem) {
        columns[index].selectedIndex = columns[index].items.firstIndex(where: { $0.id == item.id })

        guard item.isDirectory else { return }

        let newPath = columns[index].path.isEmpty ? item.name : "\(columns[index].path)/\(item.name)"

        columns = Array(columns.prefix(index + 1))

        let newCol = ColumnData(path: newPath, title: item.name, items: [], selectedIndex: nil)
        columns.append(newCol)

        Task { await loadColumn(index + 1, path: newPath) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let lastID = columns.last?.id {
                scrollProxy?.scrollTo(lastID, anchor: .trailing)
            }
        }
    }
}

private struct ColumnPane: View {
    let column: ColumnBrowserView.ColumnData
    let isLast: Bool
    let onSelect: (RemoteItem) -> Void
    let onDoubleClick: (RemoteItem) -> Void
    let onContextMenu: (RemoteItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon))))
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 14, height: 14)
                Text(column.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(column.items.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if column.items.isEmpty {
                VStack(spacing: 6) {
                    ProgressView().scaleEffect(0.5)
                    Text("Loading...").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(column.items.enumerated()), id: \.element.id, selection: Binding(
                    get: { column.selectedIndex.map { Set([$0]) } ?? Set() },
                    set: { _ in }
                )) { (index, item) in
                    ColumnItemRow(
                        item: item,
                        isSelected: column.selectedIndex == index,
                        onSelect: { onSelect(item) },
                        onDoubleClick: { onDoubleClick(item) }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 6))
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 28)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct ColumnItemRow: View {
    let item: RemoteItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            FileIcon(fileName: item.name, isDirectory: item.isDirectory, size: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if !item.isDirectory {
                    Text(item.formattedSize)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.8) : Color.clear)
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture {
            onSelect()
        }
    }
}
