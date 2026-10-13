import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            ConfigSettingsTab()
                .tabItem { Label("Config", systemImage: "doc.text") }

            TransferSettingsTab()
                .tabItem { Label("Transfers", systemImage: "arrow.triangle.2.circlepath") }

            UpdateSettingsTab()
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 420)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        Form {
            Section {
                Toggle("Start rclone daemon when Outpost opens", isOn: $preferences.startDaemonAtLaunch)

                Toggle(isOn: Binding(
                    get: { launchAtLoginController.isEnabled },
                    set: { launchAtLoginController.setEnabled($0) }
                )) {
                    Text("Open Outpost at login")
                }

                if let error = launchAtLoginController.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Startup")
            }

            Section {
                LabeledContent("Status") {
                    Label(
                        viewModel.daemonRunning ? "Running" : "Stopped",
                        systemImage: viewModel.daemonRunning ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(viewModel.daemonRunning ? Color.green : Color.secondary)
                }

                LabeledContent("rclone version") {
                    Text(viewModel.daemonVersion.isEmpty ? "Unknown" : viewModel.daemonVersion)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Remote control port") {
                    Text("5572")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Start") {
                        Task { await viewModel.startDaemon() }
                    }
                    .disabled(viewModel.daemonRunning)

                    Button("Restart") {
                        Task { await viewModel.restartDaemon() }
                    }

                    Button("Stop") {
                        viewModel.stopDaemon()
                    }
                    .disabled(!viewModel.daemonRunning)
                }
            } header: {
                Text("Daemon")
            }

            Section {
                Picker("Default browser view", selection: $preferences.browserViewMode) {
                    ForEach(BrowserViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }

                Toggle("Show transfer queue", isOn: $preferences.showTransfers)
                Toggle("Confirm before deleting files", isOn: $preferences.confirmDeletes)
            } header: {
                Text("Browsing")
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            launchAtLoginController.refresh()
        }
    }
}

private struct ConfigSettingsTab: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section {
                if let path = viewModel.currentConfigPath {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom config file active")
                            .font(.subheadline)
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Outpost keeps a security-scoped bookmark for this file when sandboxed.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Using default rclone config")
                            .font(.subheadline)
                        Text("~/.config/rclone/rclone.conf")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("Choose Config File...") {
                        viewModel.chooseConfigFile()
                    }

                    if let path = viewModel.currentConfigPath {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        }

                        Button("Reset to Default") {
                            viewModel.switchConfigPath(nil)
                        }
                    }
                }
            } header: {
                Text("Configuration File")
            }

            Section {
                LabeledContent("Configured remotes") {
                    Text("\(viewModel.remotes.count)")
                        .foregroundStyle(.secondary)
                }

                if viewModel.remotes.isEmpty {
                    Text("No remotes are available from the active rclone config.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.remotes) { remote in
                        HStack {
                            Image(systemName: RemoteIcon.forType(remote.type))
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text(remote.name)
                            Spacer()
                            Text(remote.displayType)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Remotes")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct TransferSettingsTab: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        Form {
            Section {
                Toggle("Clear completed transfers automatically", isOn: $preferences.clearCompletedTransfersAutomatically)
                Toggle("Show transfer queue in the main window", isOn: $preferences.showTransfers)
            } header: {
                Text("Queue")
            }

            Section {
                LabeledContent("Active transfers") {
                    Text("\(viewModel.transferJobs.filter { $0.status == .transferring }.count)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Completed or failed") {
                    Text("\(viewModel.transferJobs.filter { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Cancel Active") {
                        viewModel.cancelAllTransfers()
                    }
                    .disabled(!viewModel.transferJobs.contains { $0.status == .pending || $0.status == .transferring })

                    Button("Clear Completed") {
                        viewModel.clearCompletedTransfers()
                    }
                    .disabled(!viewModel.transferJobs.contains { $0.status == .completed || $0.status == .failed || $0.status == .cancelled })
                }
            } header: {
                Text("Current Session")
            }

            Section {
                Text("Uploads and downloads use the access granted by file pickers. Custom config files are stored with security-scoped bookmarks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("File Access")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct UpdateSettingsTab: View {
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var updateController: UpdateController

    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $preferences.automaticallyCheckForUpdates)

                Button("Check for Updates...") {
                    updateController.checkForUpdates()
                }

                if let summary = updateController.lastCheckSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Updates")
            }

            Section {
                Text("The repository includes an appcast placeholder and release checklist for Sparkle-based direct distribution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Release Channel")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutTab: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "externaldrive.badge.wifi")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Outpost")
                .font(.title)
                .fontWeight(.medium)

            Text("A native rclone cloud storage manager for macOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(versionText)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 240)

            VStack(spacing: 4) {
                Text("SwiftUI app with rclone Remote Control API")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("macOS 13 or later")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Link("rclone.org", destination: URL(string: "https://rclone.org")!)
                Link("GitHub Releases", destination: URL(string: "https://github.com/LJAM96/outpost/releases")!)
            }
            .font(.caption)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
