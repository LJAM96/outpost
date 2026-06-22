import Foundation

enum TransferDirection: String, Codable {
    case download
    case upload
}

enum TransferStatus: String, Codable {
    case pending
    case transferring
    case completed
    case failed
}

struct TransferJob: Identifiable, Codable {
    let id = UUID()
    let remote: String

    enum CodingKeys: String, CodingKey {
        case remote, remotePath, localPath, fileName, fileSize, direction, status, bytesTransferred, errorMessage
    }
    let remotePath: String
    let localPath: String
    let fileName: String
    let fileSize: Int64
    let direction: TransferDirection
    var status: TransferStatus
    var bytesTransferred: Int64
    var errorMessage: String?

    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(bytesTransferred) / Double(fileSize)
    }

    var formattedProgress: String {
        let pct = Int(progress * 100)
        return "\(pct)%"
    }

    var formattedTransferred: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytesTransferred)
    }

    var formattedTotal: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}
