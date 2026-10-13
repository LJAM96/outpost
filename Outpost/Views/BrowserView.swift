import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BrowserView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var commandCenter: OutpostCommandCenter
    @State private var showDeleteAlert = false
    @State private var showFileImporter = false
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedRemote != nil {
                pathBar
                Divider()
            }

            if viewModel.selectedRemote == nil {
                emptyState
            } else if viewModel.isListing && preferences.browserViewMode != .columns {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: preferences.browserViewMode)
        .animation(.easeInOut(duration: 0.15), value: viewModel.selectedRemote)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { viewModel.uploadFiles(urls) }
        }
        .alert("Delete Items", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelection(confirming: false)
            }
        } message: {
            Text("Delete \(viewModel.selectedItems.count) item(s)? This cannot be undone.")
        }
        .onChange(of: commandCenter.newFolderRequest) { _ in
            startCreatingFolder()
        }
        .onChange(of: commandCenter.uploadRequest) { _ in
            if viewModel.selectedRemote != nil { showFileImporter = true }
        }
        .onChange(of: commandCenter.downloadRequest) { _ in
            downloadSelection()
        }
        .onChange(of: commandCenter.deleteRequest) { _ in
            deleteSelection(confirming: preferences.confirmDeletes)
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
                Picker("View", selection: $preferences.browserViewMode) {
                    ForEach(BrowserViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(viewModel.selectedRemote == nil)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    downloadSelection()
                } label: { Image(systemName: "square.and.arrow.down") }
                    .disabled(viewModel.selectedItems.isEmpty || viewModel.selectedRemote == nil)
                    .help("Download")
            }

            ToolbarItem(placement: .primaryAction) {
                Button { showFileImporter = true } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(viewModel.selectedRemote == nil)
                    .help("Upload")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { Task { await viewModel.loadCurrentPath() } }
                        label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    Divider()
                    Button { startCreatingFolder() }
                        label: { Label("New Folder", systemImage: "folder.badge.plus") }
                    Divider()
                    Button(role: .destructive) {
                        deleteSelection(confirming: preferences.confirmDeletes)
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
        switch preferences.browserViewMode {
        case .list:
            ListFileView(isCreatingFolder: $isCreatingFolder, newFolderName: $newFolderName, onStartCreateFolder: startCreatingFolder, onCreateFolder: createFolder, onCancelCreateFolder: cancelCreateFolder)
                .transition(.opacity)
        case .columns:
            ColumnBrowserView()
                .transition(.opacity)
        case .icons:
            IconGridView(
                onSelect: { item in handleItemAction(item) },
                isCreatingFolder: $isCreatingFolder,
                newFolderName: $newFolderName,
                onStartCreateFolder: startCreatingFolder,
                onCreateFolder: createFolder,
                onCancelCreateFolder: cancelCreateFolder
            )
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

    private func selectedItems() -> [RemoteItem] {
        viewModel.items.filter { viewModel.selectedItems.contains($0.id) }
    }

    private func downloadSelection() {
        let items = selectedItems()
        guard !items.isEmpty else { return }
        viewModel.downloadToLocal(items)
    }

    private func deleteSelection(confirming: Bool) {
        let items = selectedItems()
        guard !items.isEmpty else { return }
        if confirming {
            showDeleteAlert = true
        } else {
            Task { await viewModel.deleteItems(items) }
        }
    }

    private func startCreatingFolder() {
        guard viewModel.selectedRemote != nil else { return }
        newFolderName = "untitled folder"
        isCreatingFolder = true
    }

    private func cancelCreateFolder() {
        isCreatingFolder = false
        newFolderName = ""
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await viewModel.createDirectory(name: trimmed)
            newFolderName = ""
            isCreatingFolder = false
        }
    }

    private var pathBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(pathComponents.enumerated()), id: \.offset) { (index, component) in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
                Button {
                    viewModel.navigateToPath(component.fullPath)
                } label: {
                    Text(component.name)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(component.isLast ? .primary : .secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
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
}

private struct ListFileView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var isCreatingFolder: Bool
    @Binding var newFolderName: String
    let onStartCreateFolder: () -> Void
    let onCreateFolder: () -> Void
    let onCancelCreateFolder: () -> Void

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
        .background(DoubleClickMonitorView(viewModel: viewModel))
        .contextMenu {
            Button { Task { await viewModel.loadCurrentPath() } }
                label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Divider()
            Button { onStartCreateFolder() }
                label: { Label("New Folder", systemImage: "folder.badge.plus") }
        }
        .overlay(alignment: .topLeading) {
            if isCreatingFolder {
                InlineFolderCreationView(
                    folderName: $newFolderName,
                    onCreate: onCreateFolder,
                    onCancel: onCancelCreateFolder
                )
                .offset(y: CGFloat(viewModel.items.count) * 22 + 4)
            }
        }
    }
}

private struct DoubleClickMonitorView: NSViewRepresentable {
    let viewModel: AppViewModel

    func makeNSView(context: Context) -> DoubleClickNSView {
        let view = DoubleClickNSView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: DoubleClickNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

private class DoubleClickNSView: NSView {
    var viewModel: AppViewModel?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handleClick(event)
                return event
            }
        } else {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handleClick(_ event: NSEvent) {
        guard event.clickCount == 2,
              let viewModel = viewModel,
              let window = window,
              window === event.window else { return }

        let locationInView = convert(event.locationInWindow, from: nil)
        guard bounds.contains(locationInView) else { return }

        if let selectedItem = viewModel.selectedItems.first,
           let item = viewModel.items.first(where: { $0.id == selectedItem }) {
            if item.isDirectory {
                viewModel.navigateInto(item)
            } else {
                viewModel.quickOpenFile(item)
            }
        }
    }
}

private struct InlineFolderCreationView: View {
    @Binding var folderName: String
    let onCreate: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    @State private var didCommit = false

    var body: some View {
        HStack(spacing: 7) {
            FileIcon(fileName: "folder", isDirectory: true, size: 20)
            TextField("", text: $folderName)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit { commitOnce() }
                .onExitCommand { onCancel() }
            Spacer()
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(Color.accentColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onAppear {
            isFocused = true
            if folderName.isEmpty { folderName = "untitled folder" }
        }
        .onChange(of: isFocused) { focused in
            // Clicking away commits (Finder-style). Only commit if there's a
            // non-blank name to avoid creating "untitled folder" accidentally.
            if !focused && !didCommit {
                let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    onCancel()
                } else {
                    commitOnce()
                }
            }
        }
    }

    private func commitOnce() {
        guard !didCommit else { return }
        didCommit = true
        onCreate()
    }
}

private struct IconGridView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let onSelect: (RemoteItem) -> Void
    @Binding var isCreatingFolder: Bool
    @Binding var newFolderName: String
    let onStartCreateFolder: () -> Void
    let onCreateFolder: () -> Void
    let onCancelCreateFolder: () -> Void

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
                            .fill(viewModel.selectedItems.contains(item.id) ? Color.accentColor.opacity(0.12) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        viewModel.selectedItems.contains(item.id) ? Color.accentColor.opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.name)
                    .accessibilityValue(item.isDirectory ? "Folder" : item.formattedSize)
                    .onTapGesture(count: 2) { onSelect(item) }
                    .onTapGesture { viewModel.selectedItems = [item.id] }
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

                if isCreatingFolder {
                    VStack(spacing: 6) {
                        FileIcon(fileName: "folder", isDirectory: true, size: 64)
                        InlineFolderCreationView(
                            folderName: $newFolderName,
                            onCreate: onCreateFolder,
                            onCancel: onCancelCreateFolder
                        )
                        .frame(width: 90)
                    }
                    .frame(width: 100, height: 110)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(16)
        }
        .contextMenu {
            Button { Task { await viewModel.loadCurrentPath() } }
                label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Divider()
            Button { onStartCreateFolder() }
                label: { Label("New Folder", systemImage: "folder.badge.plus") }
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
