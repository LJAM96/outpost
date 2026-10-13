import Foundation

enum RemoteIcon {
    static func forType(_ type: String) -> String {
        switch type.lowercased() {
        case "drive", "gcs": return "icloud"
        case "s3", "b2", "azureblob": return "server.rack"
        case "sftp", "ftp": return "network"
        case "dropbox": return "tray"
        case "onedrive": return "person.icloud"
        case "webdav": return "globe"
        case "local": return "externaldrive"
        default: return "externaldrive.badge.wifi"
        }
    }
}
