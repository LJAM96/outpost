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
                    Button("Clear Completed") {
                        viewModel.clearCompletedTransfers()
                    }
                    .font(.caption)
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
        }
    }

    private var color: Color {
        switch job.status {
        case .pending: return .secondary
        case .transferring: return .blue
        case .completed: return .green
        case .failed: return .red
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
        }
    }
}
