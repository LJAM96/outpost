import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showNewRemote = false
    @State private var editingRemote: RcloneRemote?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $viewModel.selectedRemote) {
                Section("Remotes") {
                    if viewModel.remotes.isEmpty {
                        Text("No remotes found")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.remotes) { remote in
                        RemoteRowView(
                            remote: remote,
                            isMounted: viewModel.mountedRemotes.contains(remote.name),
                            isAutoMount: viewModel.autoMountRemotes.contains(remote.name),
                            onMount: { viewModel.mountRemote(remote) },
                            onUnmount: { viewModel.unmountRemote(remote) },
                            onAutoMount: { viewModel.toggleAutoMount(remote) },
                            onEdit: { editingRemote = remote; showNewRemote = true },
                            onDelete: { Task { await viewModel.deleteRemote(remote) } }
                        )
                        .tag(remote)
                    }
                }

                Section("Status") {
                    HStack {
                        Image(systemName: viewModel.daemonRunning ? "circle.fill" : "circle")
                            .foregroundStyle(viewModel.daemonRunning ? .green : .red)
                            .font(.caption)
                        Text(viewModel.daemonRunning ? "Daemon running" : "Not running")
                            .font(.caption)
                    }

                    if !viewModel.daemonVersion.isEmpty {
                        Text("rclone \(viewModel.daemonVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(3)
                    }
                }
            }
            .listStyle(.sidebar)

            HStack {
                Button {
                    editingRemote = nil
                    showNewRemote = true
                } label: {
                    Label("Add Remote", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Add a new remote")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .onChange(of: viewModel.selectedRemote) { newValue in
            viewModel.selectRemote(newValue)
        }
        .sheet(isPresented: $showNewRemote) {
            NewRemoteView(editingRemote: editingRemote)
        }
    }
}

private struct RemoteRowView: View {
    let remote: RcloneRemote
    let isMounted: Bool
    let isAutoMount: Bool
    let onMount: () -> Void
    let onUnmount: () -> Void
    let onAutoMount: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Label {
            Text(remote.name)
            Text(remote.displayType)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: iconForType(remote.type))
                .foregroundStyle(.blue)
        }
        .contextMenu {
            if isMounted {
                Button(action: onUnmount) {
                    Label("Unmount", systemImage: "eject")
                }
            } else {
                Button(action: onMount) {
                    Label("Mount", systemImage: "externaldrive")
                }
            }
            Button(action: onAutoMount) {
                Label(
                    isAutoMount ? "Disable Auto-Mount" : "Auto-Mount on Start",
                    systemImage: isAutoMount ? "checkmark.circle.fill" : "clock"
                )
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit Remote", systemImage: "pencil")
            }
            Divider()
            Button(action: onDelete) {
                Label("Delete Remote", systemImage: "trash")
            }
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "drive", "gcs": return "icloud"
        case "s3", "b2", "azureblob": return "server.rack"
        case "sftp", "ftp": return "network"
        case "dropbox": return "tray"
        case "onedrive": return "person.icloud"
        case "webdav": return "globe"
        case "local": return "externaldrive"
        default: return "externaldrive.badge.wifi"
        }
    }
}
