import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var commandCenter: OutpostCommandCenter

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                statusArea
                HStack(spacing: 0) {
                    BrowserView()
                    if preferences.showTransfers {
                        Divider()
                        TransferQueueView()
                            .frame(width: 300)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
                        preferences.showTransfers.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Toggle transfer queue")
            }
        }
        .task {
            await viewModel.checkDaemon()
        }
        .onChange(of: commandCenter.toggleTransfersRequest) { _ in
            withAnimation {
                preferences.showTransfers.toggle()
            }
        }
        .onChange(of: commandCenter.refreshRequest) { _ in
            Task { await viewModel.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.checkDaemon() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rcloneDaemonStatusChanged)) { _ in
            Task { await viewModel.checkDaemon() }
        }
    }

    private var sidebar: some View {
        SidebarView()
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh remotes")
                }
            }
    }

    @ViewBuilder
    private var statusArea: some View {
        if !viewModel.daemonRunning {
            StatusBannerView(
                title: "rclone daemon is not running",
                message: viewModel.errorMessage,
                systemImage: "bolt.horizontal.circle",
                tint: .orange,
                actionTitle: "Start",
                action: { Task { await viewModel.startDaemon() } },
                dismiss: viewModel.errorMessage == nil ? nil : { viewModel.clearError() }
            )
            Divider()
        } else if let error = viewModel.errorMessage {
            StatusBannerView(
                title: "Action needed",
                message: error,
                systemImage: "exclamationmark.triangle",
                tint: .red,
                dismiss: { viewModel.clearError() }
            )
            Divider()
        }
    }
}
