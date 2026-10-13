import SwiftUI

struct TransferQueueView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transfers")
                    .font(.headline)

                Spacer()

                if !viewModel.transferJobs.isEmpty {
                    HStack(spacing: 8) {
                        Button {
                            viewModel.cancelAllTransfers()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!viewModel.transferJobs.contains { $0.status == .pending || $0.status == .transferring })
                        .help("Cancel active transfers")

                        Button("Clear Completed") {
                            viewModel.clearCompletedTransfers()
                        }
                        .font(.caption)
                        .disabled(!viewModel.transferJobs.contains {
                            $0.status == .completed || $0.status == .failed || $0.status == .cancelled
                        })
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if viewModel.transferJobs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No transfers")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    overallProgressSection

                    ForEach(viewModel.transferJobs) { job in
                        TransferJobRow(job: job)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
    }

    private var overallProgressSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.overallProgress.speed > 0 {
                        Text(formattedSpeed(viewModel.overallProgress.speed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.overallProgress.total > 0 {
                    ProgressView(value: Double(viewModel.overallProgress.bytes), total: Double(viewModel.overallProgress.total))
                } else if viewModel.transferJobs.contains(where: { $0.status == .transferring }) {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }
        }
    }

    private func formattedSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
}

struct TransferJobRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let job: TransferJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.fileName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(job.remote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    statusText
                    if job.fileSize > 0 && job.status == .transferring {
                        Text("\(job.formattedTransferred) / \(job.formattedTotal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if job.status == .pending || job.status == .transferring {
                    Button {
                        viewModel.cancelTransfer(job)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Cancel transfer")
                    .help("Cancel")
                } else if job.status == .failed || job.status == .cancelled {
                    Button {
                        viewModel.retryTransfer(job)
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Retry transfer")
                    .help("Retry")
                }
            }

            if job.status == .transferring && job.fileSize > 0 {
                ProgressView(value: job.progress)
            }

            if let error = job.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch job.status {
        case .pending: return "clock"
        case .transferring: return "arrow.triangle.swap"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "minus.circle"
        }
    }

    private var color: Color {
        switch job.status {
        case .pending: return .secondary
        case .transferring: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch job.status {
        case .pending:
            Text("Pending")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .transferring:
            Text(job.formattedProgress)
                .font(.caption)
                .foregroundStyle(.blue)
        case .completed:
            Text("Complete")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Text("Failed")
                .font(.caption)
                .foregroundStyle(.red)
        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
