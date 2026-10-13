import Foundation

enum RclonePath {
    static func fs(remote: String, path: String) -> String {
        guard remote.isEmpty else { return "\(remote):\(path)" }
        return path.hasPrefix("/") ? path : "/\(path)"
    }

    static func childPath(basePath: String, itemName: String) -> String {
        basePath.isEmpty ? itemName : "\(basePath)/\(itemName)"
    }
}

