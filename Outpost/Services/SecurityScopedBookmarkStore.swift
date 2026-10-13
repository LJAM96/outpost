import Foundation

final class SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    enum Key {
        static let rcloneConfig = "securityScopedBookmark.rcloneConfig"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveBookmark(for url: URL, key: String) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        defaults.set(data, forKey: key)
    }

    func resolvedURL(for key: String) -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale {
            saveBookmark(for: url, key: key)
        }
        return url
    }

    func removeBookmark(for key: String) {
        defaults.removeObject(forKey: key)
    }
}
