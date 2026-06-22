import SwiftUI
import UniformTypeIdentifiers

enum BrowserViewMode: String, CaseIterable {
    case list = "List"
    case columns = "Columns"
    case icons = "Icons"

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .columns: return "rectangle.split.3x1"
        case .icons: return "square.grid.2x2"
        }
    }
}

struct BrowserView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var showDeleteAlert = false
    @State private var sortOrder = [KeyPathComparator(\RemoteItem.name)]
    @State private var showFileImporter = false
    @State private var viewMode: BrowserViewMode = .list

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedRemote != nil {
                pathBar
                Divider()
            }

            if viewModel.selectedRemote == nil {
                emptyState
            } else if viewModel.isListing && viewMode != .columns {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewMode)
        .animation(.easeInOut(duration: 0.15), value: viewModel.selectedRemote)
        .sheet(isPresented: $showNewFolderSheet) { newFolderSheet }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { viewModel.uploadFiles(urls) }
        }
        .alert("Delete Items", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let toDelete = viewModel.items.filter { viewModel.selectedItems.contains($0.id) }
                Task { await viewModel.deleteItems(toDelete) }
            }
        } message: {
            Text("Delete \(viewModel.selectedItems.count) item(s)? This cannot be undone.")
        }
        .modifier(KeyPressModifier(viewModel: viewModel))
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, _) in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { viewModel.uploadFiles([url]) }
                }
            }
            return true
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { viewModel.navigateUp() } label: { Image(systemName: "chevron.backward") }
                    .disabled(viewModel.currentPath.isEmpty || viewModel.selectedRemote == nil)
                    .help("Back")
            }

            ToolbarItem {
                Picker("View", selection: $viewMode) {
                    ForEach(BrowserViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(viewModel.selectedRemote == nil)
            }

            ToolbarItemGroup {
                Button {
                    let toDownload = viewModel.items.filter { viewModel.selectedItems.contains($0.id) }
                    viewModel.downloadToLocal(toDownload)
                } label: { Image(systemName: "square.and.arrow.down") }
                    .disabled(viewModel.selectedItems.isEmpty || viewModel.selectedRemote == nil)
                    .help("Download")

                Button { showFileImporter = true } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(viewModel.selectedRemote == nil)
                    .help("Upload")

                Menu {
                    Button { showNewFolderSheet = true }
                        label: { Label("New Folder", systemImage: "folder.badge.plus") }
                    Divider()
                    Button(role: .destructive) {
                        let toDelete = viewModel.items.filter { viewModel.selectedItems.contains($0.id) }
                        if !toDelete.isEmpty { showDeleteAlert = true }
                    } label: { Label("Delete", systemImage: "trash") }
                        .disabled(viewModel.selectedItems.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(viewModel.selectedRemote == nil)
                .help("Actions")
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .list:
            ListFileView()
                .transition(.opacity)
        case .columns:
            ColumnBrowserView()
                .transition(.opacity)
        case .icons:
            IconGridView(onSelect: { item in handleItemAction(item) })
                .transition(.opacity)
        }
    }

    private func handleItemAction(_ item: RemoteItem) {
        if item.isDirectory {
            viewModel.navigateInto(item)
        } else {
            viewModel.quickOpenFile(item)
        }
    }

    private var pathBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(pathComponents.enumerated()), id: \.offset) { (index, component) in
                if index > 0 {
                    Text("›")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 2)
                }
                Button {
                    viewModel.navigateToPath(component.fullPath)
                } label: {
                    Text(component.name)
                }
                .buttonStyle(.plain)
                .fontWeight(component.isLast ? .semibold : .regular)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var pathComponents: [(name: String, fullPath: String, isLast: Bool)] {
        guard let remote = viewModel.selectedRemote else { return [] }
        let root = (name: remote.name, fullPath: "", isLast: viewModel.currentPath.isEmpty)
        var result = [root]
        let parts = viewModel.currentPath.split(separator: "/").map(String.init)
        for (i, part) in parts.enumerated() {
            let fullPath = parts[0...i].joined(separator: "/")
            result.append((name: part, fullPath: fullPath, isLast: i == parts.count - 1))
        }
        return result
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 56, weight: .light)).foregroundStyle(.quaternary)
            Text("No Remote Selected").font(.title3).foregroundStyle(.secondary)
            Text("Select a remote from the sidebar to browse files.")
                .font(.body).foregroundStyle(.tertiary).multilineTextAlignment(.center).frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var newFolderSheet: some View {
        VStack(spacing: 20) {
            Text("New Folder").font(.headline)
            TextField("Folder name", text: $newFolderName).textFieldStyle(.roundedBorder).frame(width: 250)
            HStack(spacing: 12) {
                Button("Cancel") { showNewFolderSheet = false; newFolderName = "" }.keyboardShortcut(.escape)
                Button("Create") {
                    Task { await viewModel.createDirectory(name: newFolderName); newFolderName = ""; showNewFolderSheet = false }
                }.keyboardShortcut(.return).disabled(newFolderName.isEmpty)
            }
        }.padding(24)
    }
}

private struct ListFileView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        if #available(macOS 14.0, *) {
            list
                .alternatingRowBackgrounds(.enabled)
        } else {
            list
        }
    }

    private var list: some View {
        List(viewModel.items, selection: $viewModel.selectedItems) { item in
            Button {
                if item.isDirectory {
                    viewModel.navigateInto(item)
                } else {
                    viewModel.quickOpenFile(item)
                }
            } label: {
                HStack(spacing: 7) {
                    FileIcon(fileName: item.name, isDirectory: item.isDirectory, size: 20)
                    Text(item.name).font(.system(size: 13)).lineLimit(1)
                    Spacer()
                    Text(item.formattedSize)
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
                    Text(item.formattedDate)
                        .font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 140, alignment: .trailing)
                }
                .padding(.vertical, 1)
            }
            .buttonStyle(.plain)
            .contextMenu {
                if item.isDirectory {
                    Button { viewModel.navigateInto(item) }
                        label: { Label("Open", systemImage: "arrow.right.circle") }
                    Button { viewModel.downloadToLocal([item]) }
                        label: { Label("Download Folder", systemImage: "arrow.down.circle") }
                } else {
                    Button { viewModel.quickOpenFile(item) }
                        label: { Label("Quick Open", systemImage: "play.circle") }
                    Button { viewModel.downloadToLocal([item]) }
                        label: { Label("Download", systemImage: "arrow.down.circle") }
                }
                Divider()
                Button(role: .destructive) {
                    Task { await viewModel.deleteItems([item]) }
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .listStyle(.inset)
    }
}

private struct IconGridView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let onSelect: (RemoteItem) -> Void

    @State private var selectedID: RemoteItem.ID?

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.items) { item in
                    VStack(spacing: 6) {
                        if item.isDirectory {
                            FileIcon(fileName: item.name, isDirectory: true, size: 64)
                        } else {
                            ThumbnailView(item: item, size: 64)
                        }

                        Text(item.name)
                            .font(.system(size: 11))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: 90)

                        if !item.isDirectory {
                            Text(item.formattedSize)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
    }
}
                    .frame(width: 100, height: 110)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedID == item.id ? Color.accentColor.opacity(0.12) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedID == item.id ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onSelect(item) }
                    .onTapGesture { selectedID = item.id }
                    .contextMenu {
                        if item.isDirectory {
                            Button { viewModel.navigateInto(item) }
                                label: { Label("Open", systemImage: "arrow.right.circle") }
                            Button { viewModel.downloadToLocal([item]) }
                                label: { Label("Download Folder", systemImage: "arrow.down.circle") }
                        } else {
                            Button { viewModel.quickOpenFile(item) }
                                label: { Label("Quick Open", systemImage: "play.circle") }
                            Button { viewModel.downloadToLocal([item]) }
                                label: { Label("Download", systemImage: "arrow.down.circle") }
                        }
                        Divider()
                        Button(role: .destructive) {
                            Task { await viewModel.deleteItems([item]) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct KeyPressModifier: ViewModifier {
    let viewModel: AppViewModel

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.leftArrow) {
                    if viewModel.selectedItems.isEmpty { viewModel.navigateUp(); return .handled }
                    return .ignored
                }
                .onKeyPress(.rightArrow) {
                    if viewModel.selectedItems.count == 1,
                       let item = viewModel.items.first(where: { viewModel.selectedItems.contains($0.id) }),
                       item.isDirectory { viewModel.navigateInto(item); return .handled }
                    return .ignored
                }
                .onKeyPress(.return) {
                    if viewModel.selectedItems.count == 1,
                       let item = viewModel.items.first(where: { viewModel.selectedItems.contains($0.id) }) {
                        if item.isDirectory { viewModel.navigateInto(item) }
                        else { viewModel.quickOpenFile(item) }
                        return .handled
                    }
                    return .ignored
                }
        } else {
            content
        }
    }
}
