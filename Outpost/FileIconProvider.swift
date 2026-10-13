import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FileIconProvider {
    static let shared = FileIconProvider()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(for fileName: String, isDirectory: Bool, size: CGFloat = 16) -> NSImage {
        let cacheKey = isDirectory ? "__folder__:\(size)" : "\(fileName):\(size)"

        if let cached = cache[cacheKey] { return cached }

        let icon: NSImage
        if isDirectory {
            icon = NSWorkspace.shared.icon(for: .folder)
        } else {
            let ext = (fileName as NSString).pathExtension.lowercased()
            if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
                icon = NSWorkspace.shared.icon(for: type)
            } else {
                icon = NSWorkspace.shared.icon(for: .data)
            }
        }

        cache[cacheKey] = icon
        return icon
    }
}

struct FileIcon: View {
    let fileName: String
    let isDirectory: Bool
    var size: CGFloat = 16

    var body: some View {
        Image(nsImage: FileIconProvider.shared.icon(for: fileName, isDirectory: isDirectory, size: size))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
