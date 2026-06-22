import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            ConfigSettingsTab()
                .tabItem { Label("Config", systemImage: "doc.text") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Start daemon at launch", isOn: .constant(true))
                    .disabled(true)
                    .help("The rclone daemon always starts automatically")

                if !viewModel.autoMountRemotes.isEmpty {
                    Text("Auto-mount remotes:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(viewModel.remotes) { remote in
                        if viewModel.autoMountRemotes.contains(remote.name) {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundStyle(.green)
                                Text(remote.name)
                                Spacer()
                                Text(remote.displayType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text("Right-click a remote in the sidebar to toggle auto-mount.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Text("rclone version")
                    Spacer()
                    Text(viewModel.daemonVersion.isEmpty ? "unknown" : viewModel.daemonVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Daemon port")
                    Spacer()
                    Text("5572")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Daemon")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ConfigSettingsTab: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section {
                HStack {
                    if let path = viewModel.currentConfigPath {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom config file active")
                                .font(.subheadline)
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text((path as NSString).deletingLastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Using default config")
                                .font(.subheadline)
                            Text("~/.config/rclone/rclone.conf")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                HStack {
                    Button("Choose Config File...") {
                        viewModel.chooseConfigFile()
                    }

                    if viewModel.currentConfigPath != nil {
                        Button("Reset to Default") {
                            viewModel.switchConfigPath(nil)
                        }
                    }
                }

                if viewModel.currentConfigPath != nil {
                    Text("Restart the app to apply config changes.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Configuration File")
            }

            Section {
                HStack {
                    Text("Configured remotes")
                    Spacer()
                    Text("\(viewModel.remotes.count)")
                        .foregroundStyle(.secondary)
                }

                if !viewModel.remotes.isEmpty {
                    ForEach(viewModel.remotes) { remote in
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text(remote.name)
                                .font(.caption)
                            Spacer()
                            Text(remote.displayType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Remotes")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "externaldrive.badge.wifi")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Outpost")
                .font(.title)
                .fontWeight(.medium)

            Text("rclone cloud storage manager")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 4) {
                Text("Built with SwiftUI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Uses rclone Remote Control API")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("macOS 13+")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Link("rclone.org", destination: URL(string: "https://rclone.org")!)
                .font(.caption)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
