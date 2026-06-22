import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showTransfers = false

    var body: some View {
        if #available(macOS 14.0, *) {
            modernLayout
        } else {
            legacyLayout
        }
    }

    @available(macOS 14.0, *)
    private var modernLayout: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            BrowserView()
        }
        .inspector(isPresented: $showTransfers) {
            TransferQueueView()
                .inspectorColumnWidth(min: 240, ideal: 300)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showTransfers.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Toggle transfer queue")
            }
        }
        .task {
            await viewModel.checkDaemon()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.checkDaemon() }
        }
    }

    private var legacyLayout: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if showTransfers {
                HStack(spacing: 0) {
                    BrowserView()
                    Divider()
                    TransferQueueView()
                        .frame(minWidth: 240, idealWidth: 300)
                }
            } else {
                BrowserView()
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showTransfers.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Toggle transfer queue")
            }
        }
        .task {
            await viewModel.checkDaemon()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.checkDaemon() }
        }
    }

    private var sidebar: some View {
        SidebarView()
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await viewModel.checkDaemon() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh remotes")
                }
            }
    }
}
