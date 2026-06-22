import SwiftUI

@main
struct OutpostApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear { startRcloneDaemon() }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Folder") {}
                    .keyboardShortcut("n", modifiers: [.shift, .command])
            }
            CommandMenu("Remote") {
                Button("Refresh") {
                    Task { await viewModel.checkDaemon() }
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Upload Files...") {}
                    .keyboardShortcut("u", modifiers: .command)
                Button("Download Selected") {
                    let toDownload = viewModel.items.filter { viewModel.selectedItems.contains($0.id) }
                    viewModel.downloadToLocal(toDownload)
                }
                .keyboardShortcut("d", modifiers: .command)
            }
            CommandMenu("Transfers") {
                Button("Clear Completed") {
                    viewModel.clearCompletedTransfers()
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }

        MenuBarExtra {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: viewModel.daemonRunning ? "circle.fill" : "circle")
                        .foregroundStyle(viewModel.daemonRunning ? .green : .red)
                        .font(.caption)
                    Text(viewModel.daemonRunning ? "rclone \(viewModel.daemonVersion)" : "Daemon off")
                        .font(.system(size: 11))
                }
                Divider()
                if viewModel.remotes.isEmpty {
                    Text("No remotes configured")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.remotes) { remote in
                        Button {
                            NSApp.activate(ignoringOtherApps: true)
                            viewModel.selectRemote(remote)
                        } label: {
                            Label(remote.displayName, systemImage: MenuIcon.forType(remote.type))
                        }
                    }
                }
                Divider()
                if let firstJob = viewModel.transferJobs.first(where: { $0.status == .transferring }) {
                    HStack {
                        ProgressView().scaleEffect(0.6)
                        Text("\(firstJob.fileName) (\(firstJob.formattedProgress))").font(.caption)
                    }
                    Divider()
                }
                Button("Show Window") { NSApp.activate(ignoringOtherApps: true) }
                Button("Quit Outpost") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }
            .padding(8)
            .frame(width: 220)
        } label: {
            Image(systemName: "externaldrive.badge.wifi")
        }
    }

    private func startRcloneDaemon() {
        Task {
            guard !viewModel.daemonRunning else { return }
            guard let rclonePath = RcloneLauncher.findRclonePath() else {
                viewModel.errorMessage = "rclone not found"
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: rclonePath)
            var args = ["rcd", "--rc-addr=localhost:5572", "--rc-no-auth"]
            if let configPath = viewModel.currentConfigPath {
                args.append(contentsOf: ["--config", configPath])
            }
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in
                Task { @MainActor in
                    viewModel.daemonRunning = false
                }
            }
            do {
                try process.run()
                try await Task.sleep(nanoseconds: 1_500_000_000)
                await viewModel.checkDaemon()
                if !viewModel.daemonRunning {
                    viewModel.errorMessage = "Rclone daemon failed to start"
                }
            } catch {
                viewModel.errorMessage = "Failed to start daemon: \(error.localizedDescription)"
            }
        }
    }
}

private enum MenuIcon {
    static func forType(_ type: String) -> String {
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
