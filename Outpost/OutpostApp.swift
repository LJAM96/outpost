import AppKit
import SwiftUI

@main
struct OutpostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var daemonController = RcloneDaemonController.shared
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var commandCenter = OutpostCommandCenter.shared
    @StateObject private var launchAtLoginController = LaunchAtLoginController.shared
    @StateObject private var updateController = UpdateController.shared

    var body: some Scene {
        WindowGroup("Outpost", id: "main") {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(daemonController)
                .environmentObject(preferences)
                .environmentObject(commandCenter)
                .environmentObject(launchAtLoginController)
                .environmentObject(updateController)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1080, height: 680)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Folder") {
                    commandCenter.requestNewFolder()
                }
                .disabled(viewModel.selectedRemote == nil)
                    .keyboardShortcut("n", modifiers: [.shift, .command])
            }
            CommandMenu("Remote") {
                Button("Refresh") {
                    commandCenter.requestRefresh()
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Upload Files...") {
                    commandCenter.requestUpload()
                }
                .disabled(viewModel.selectedRemote == nil)
                    .keyboardShortcut("u", modifiers: .command)
                Button("Download Selected") {
                    commandCenter.requestDownload()
                }
                .disabled(viewModel.selectedItems.isEmpty)
                .keyboardShortcut("d", modifiers: .command)
                Button("Delete Selected") {
                    commandCenter.requestDelete()
                }
                .disabled(viewModel.selectedItems.isEmpty)
                .keyboardShortcut(.delete, modifiers: [])
                Divider()
                Button("Restart Daemon") {
                    Task { await viewModel.restartDaemon() }
                }
            }
            CommandMenu("Transfers") {
                Button("Show Transfers") {
                    commandCenter.requestToggleTransfers()
                }
                .keyboardShortcut("0", modifiers: [.command])
                Divider()
                Button("Cancel Active Transfers") {
                    viewModel.cancelAllTransfers()
                }
                .disabled(!viewModel.transferJobs.contains { $0.status == .pending || $0.status == .transferring })
                Button("Clear Completed") {
                    viewModel.clearCompletedTransfers()
                }
                .disabled(!viewModel.transferJobs.contains { $0.status == .completed || $0.status == .failed || $0.status == .cancelled })
            }
            SidebarCommands()
            ToolbarCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(daemonController)
                .environmentObject(preferences)
                .environmentObject(commandCenter)
                .environmentObject(launchAtLoginController)
                .environmentObject(updateController)
        }

        MenuBarExtra {
            OutpostMenuBarView()
                .environmentObject(viewModel)
                .environmentObject(daemonController)
                .environmentObject(preferences)
                .environmentObject(commandCenter)
                .environmentObject(updateController)
        } label: {
            Image(systemName: "externaldrive.badge.wifi")
        }
    }
}

private struct OutpostMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var daemonController: RcloneDaemonController
    @EnvironmentObject var commandCenter: OutpostCommandCenter
    @EnvironmentObject var updateController: UpdateController

    var body: some View {
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
                        openWindow(id: "main")
                        if #available(macOS 14, *) { NSApp.activate() }
                        viewModel.selectRemote(remote)
                    } label: {
                        Label(remote.displayName, systemImage: RemoteIcon.forType(remote.type))
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
            if let error = daemonController.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                Divider()
            }
            Button("Show Window") {
                openWindow(id: "main")
                if #available(macOS 14, *) { NSApp.activate() }
            }
            Button("Upload Files...") {
                openWindow(id: "main")
                if #available(macOS 14, *) { NSApp.activate() }
                commandCenter.requestUpload()
            }
            .disabled(viewModel.selectedRemote == nil)
            Button("Check for Updates...") {
                updateController.checkForUpdates()
            }
            Divider()
            Button("Restart Daemon") {
                Task { await viewModel.restartDaemon() }
            }
            Button("Quit Outpost") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 220)
    }
}
