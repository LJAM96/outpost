import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showTransfers = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            HStack(spacing: 0) {
                BrowserView()
                if showTransfers {
                    Divider()
                    TransferQueueView()
                        .frame(width: 280)
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
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
