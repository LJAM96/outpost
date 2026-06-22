import Foundation

struct RcloneRemote: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let type: String
    let path: String

    init(name: String, type: String, path: String = "") {
        self.name = name
        self.type = type
        self.path = path
    }

    var displayName: String {
        "\(name):"
    }

    var displayType: String {
        type
            .replacingOccurrences(of: "drive", with: "Drive")
            .replacingOccurrences(of: "s3", with: "S3")
            .replacingOccurrences(of: "sftp", with: "SFTP")
            .replacingOccurrences(of: "webdav", with: "WebDAV")
            .replacingOccurrences(of: "dropbox", with: "Dropbox")
            .replacingOccurrences(of: "onedrive", with: "OneDrive")
            .replacingOccurrences(of: "gcs", with: "GCS")
            .replacingOccurrences(of: "azureblob", with: "Azure")
            .replacingOccurrences(of: "b2", with: "B2")
    }
}
