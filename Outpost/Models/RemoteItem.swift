import Foundation

struct RemoteItem: Identifiable, Hashable, Codable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modTime: Date?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case path = "Path"
        case isDirectory = "IsDir"
        case size = "Size"
        case modTime = "ModTime"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? name
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        size = try container.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        if let modTimeString = try container.decodeIfPresent(String.self, forKey: .modTime) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            modTime = formatter.date(from: modTimeString)
        } else {
            modTime = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encode(size, forKey: .size)
        if let modTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: modTime), forKey: .modTime)
        }
    }

    init(name: String, path: String, isDirectory: Bool, size: Int64, modTime: Date?) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modTime = modTime
    }

    var formattedSize: String {
        if isDirectory { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var formattedDate: String {
        guard let modTime else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modTime)
    }
}
